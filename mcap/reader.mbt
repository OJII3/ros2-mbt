///|
const MCAP_MAGIC : Bytes = b"\x89MCAP0\r\n"

///|
const MCAP_MAX_RECORD_BYTES : Int32 = 268_435_456

///|
const MCAP_MAX_STRING_BYTES : Int32 = 1_048_576

///|
/// MCAP records needed to read a message stream.
pub enum Record {
  Schema(UInt16, String, String, Bytes)
  Channel(UInt16, UInt16, String, String, Array[(String, String)])
  Message(UInt16, UInt32, UInt64, UInt64, Bytes)
  Metadata(String, Array[(String, String)])
  DataEnd
}

///|
/// A streaming MCAP reader. Chunk records with no compression are expanded
/// into the same record stream as unchunked files.
pub struct Reader {
  priv source : &@io.Reader
  priv profile : String
  priv mut chunk : Bytes?
  priv mut chunk_offset : Int32
  priv mut ended : Bool
}

///|
priv struct Cursor {
  bytes : Bytes
  mut offset : Int32
}

///|
fn Cursor::new(bytes : Bytes) -> Cursor {
  { bytes, offset: 0, }
}

///|
fn Cursor::remaining(self : Cursor) -> Int32 {
  self.bytes.length() - self.offset
}

///|
fn Cursor::take(self : Cursor, count : Int32) -> Result[Bytes, String] {
  if count < 0 || count > self.remaining() {
    return Err("truncated MCAP record")
  }
  let start = self.offset
  self.offset += count
  Ok(self.bytes[start:self.offset].to_owned())
}

///|
fn Cursor::read_u8(self : Cursor) -> Result[Byte, String] {
  match self.take(1) {
    Ok(bytes) => Ok(bytes[0])
    Err(message) => Err(message)
  }
}

///|
fn Cursor::read_u16(self : Cursor) -> Result[UInt16, String] {
  let bytes = match self.take(2) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(
    (bytes[0].to_int().reinterpret_as_uint() |
    (bytes[1].to_int().reinterpret_as_uint() << 8)).to_uint16(),
  )
}

///|
fn Cursor::read_u32(self : Cursor) -> Result[UInt32, String] {
  let bytes = match self.take(4) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(
    bytes[0].to_int().reinterpret_as_uint() |
    (bytes[1].to_int().reinterpret_as_uint() << 8) |
    (bytes[2].to_int().reinterpret_as_uint() << 16) |
    (bytes[3].to_int().reinterpret_as_uint() << 24),
  )
}

///|
fn Cursor::read_u64(self : Cursor) -> Result[UInt64, String] {
  let bytes = match self.take(8) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let mut value = 0UL
  for index in 0..<8 {
    value = value | (bytes[index].to_int().to_uint64() << (index * 8))
  }
  Ok(value)
}

///|
fn Cursor::read_string(self : Cursor) -> Result[String, String] {
  let length = match self.read_u32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if length > MCAP_MAX_STRING_BYTES.reinterpret_as_uint() {
    return Err("MCAP string exceeds the supported size limit")
  }
  let bytes = match self.take(length.reinterpret_as_int()) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(@utf8.decode(bytes)) catch {
    _ => Err("MCAP string is not valid UTF-8")
  }
}

///|
fn Cursor::finish(self : Cursor) -> Result[Unit, String] {
  if self.remaining() != 0 {
    return Err("unexpected trailing bytes in MCAP record")
  }
  Ok(())
}

///|
async fn read_exactly(
  source : &@io.Reader,
  count : Int32,
  context : String,
) -> Result[Bytes, String] {
  Ok(source.read_exactly(count)) catch {
    _ => Err("truncated MCAP " + context)
  }
}

///|
async fn read_raw_record(source : &@io.Reader) -> Result[(Byte, Bytes), String] {
  let opcode = match read_exactly(source, 1, "record opcode") {
    Ok(value) => value[0]
    Err(message) => return Err(message)
  }
  let encoded_length = match read_exactly(source, 8, "record length") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let length = match Cursor::new(encoded_length).read_u64() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if length > MCAP_MAX_RECORD_BYTES.to_uint64() {
    return Err("MCAP record exceeds the 256 MiB size limit")
  }
  let payload = match read_exactly(source, length.to_int(), "record payload") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok((opcode, payload))
}

///|
async fn read_required_header(source : &@io.Reader) -> Result[String, String] {
  let magic = match read_exactly(source, MCAP_MAGIC.length(), "header magic") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if magic != MCAP_MAGIC {
    return Err("input does not start with MCAP magic")
  }
  let (opcode, payload) = match read_raw_record(source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if opcode != 0x01 {
    return Err("MCAP Header record must be the first record")
  }
  let cursor = Cursor::new(payload)
  let profile = match cursor.read_string() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match cursor.read_string() {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match cursor.finish() {
    Ok(_) => Ok(profile)
    Err(message) => Err(message)
  }
}

///|
/// Open an MCAP stream from any async reader, including a file or memory reader.
pub async fn Reader::new(source : &@io.Reader) -> Result[Reader, String] {
  let profile = match read_required_header(source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ source, profile, chunk: None, chunk_offset: 0, ended: false, })
}

///|
/// Return the MCAP profile from the file Header record.
pub fn Reader::profile(self : Reader) -> String {
  self.profile
}

///|
fn parse_record(opcode : Byte, payload : Bytes) -> Result[Record?, String] {
  let cursor = Cursor::new(payload)
  match opcode {
    0x03 => {
      let id = match cursor.read_u16() {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let name = match cursor.read_string() {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let encoding = match cursor.read_string() {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let data_length = match cursor.read_u32() {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let data = match cursor.take(data_length.reinterpret_as_int()) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      match cursor.finish() {
        Ok(_) => Ok(Some(Schema(id, name, encoding, data)))
        Err(message) => Err(message)
      }
    }
    0x04 => {
      let id = match cursor.read_u16() {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let schema_id = match cursor.read_u16() {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let topic = match cursor.read_string() {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let message_encoding = match cursor.read_string() {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let metadata_length = match cursor.read_u32() {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let metadata_bytes = match
        cursor.take(metadata_length.reinterpret_as_int()) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      match cursor.finish() {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
      let metadata_cursor = Cursor::new(metadata_bytes)
      let metadata : Array[(String, String)] = []
      while metadata_cursor.remaining() > 0 {
        let key = match metadata_cursor.read_string() {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        let value = match metadata_cursor.read_string() {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        metadata.push((key, value))
      }
      Ok(Some(Channel(id, schema_id, topic, message_encoding, metadata)))
    }
    0x05 => {
      let channel_id = match cursor.read_u16() {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let sequence = match cursor.read_u32() {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let log_time = match cursor.read_u64() {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let publish_time = match cursor.read_u64() {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let data = match cursor.take(cursor.remaining()) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      Ok(Some(Message(channel_id, sequence, log_time, publish_time, data)))
    }
    0x0C => {
      let name = match cursor.read_string() {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let metadata_length = match cursor.read_u32() {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let metadata_bytes = match
        cursor.take(metadata_length.reinterpret_as_int()) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      match cursor.finish() {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
      let metadata_cursor = Cursor::new(metadata_bytes)
      let metadata : Array[(String, String)] = []
      while metadata_cursor.remaining() > 0 {
        let key = match metadata_cursor.read_string() {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        let value = match metadata_cursor.read_string() {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        metadata.push((key, value))
      }
      Ok(Some(Metadata(name, metadata)))
    }
    0x0F => {
      match cursor.take(4) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
      match cursor.finish() {
        Ok(_) => Ok(Some(DataEnd))
        Err(message) => Err(message)
      }
    }
    _ => Ok(None)
  }
}

///|
fn parse_chunk(payload : Bytes) -> Result[Bytes, String] {
  let cursor = Cursor::new(payload)
  for _ in 0..<2 {
    match cursor.read_u64() {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  let uncompressed_size = match cursor.read_u64() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let expected_crc = match cursor.read_u32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let compression = match cursor.read_string() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let compressed_size = match cursor.read_u64() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if compression != "" {
    return Err("unsupported MCAP chunk compression: " + compression)
  }
  if compressed_size > MCAP_MAX_RECORD_BYTES.to_uint64() {
    return Err("MCAP chunk exceeds the 256 MiB size limit")
  }
  if uncompressed_size != compressed_size {
    return Err("MCAP uncompressed chunk size does not match its record data")
  }
  let records = match cursor.take(compressed_size.to_int()) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match cursor.finish() {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  if expected_crc != 0 && crc32(records) != expected_crc {
    return Err("MCAP chunk CRC32 mismatch")
  }
  Ok(records)
}

///|
fn crc32(bytes : Bytes) -> UInt32 {
  let mut crc = 0xFFFFFFFFU
  for byte in bytes {
    crc = crc ^ byte.to_int().reinterpret_as_uint()
    for _ in 0..<8 {
      crc = if (crc & 1U) == 1U { (crc >> 1) ^ 0xEDB88320U } else { crc >> 1 }
    }
  }
  crc ^ 0xFFFFFFFFU
}

///|
fn next_record_in_chunk(
  bytes : Bytes,
  offset : Int32,
) -> Result[(Byte, Bytes, Int32), String] {
  let cursor = Cursor::new(bytes)
  cursor.offset = offset
  let opcode = match cursor.read_u8() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let length = match cursor.read_u64() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if length > MCAP_MAX_RECORD_BYTES.to_uint64() {
    return Err("MCAP record inside chunk exceeds the size limit")
  }
  let payload = match cursor.take(length.to_int()) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok((opcode, payload, cursor.offset))
}

///|
/// Read the next Schema, Channel, Message, or DataEnd record.
/// Unknown MCAP records are skipped. Chunks are flattened into this stream.
pub async fn Reader::next_record(self : Reader) -> Result[Record?, String] {
  if self.ended {
    return Ok(None)
  }
  while true {
    match self.chunk {
      Some(bytes) if self.chunk_offset < bytes.length() => {
        let (opcode, payload, next_offset) = match
          next_record_in_chunk(bytes, self.chunk_offset) {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        self.chunk_offset = next_offset
        match parse_record(opcode, payload) {
          Ok(Some(DataEnd)) => {
            self.ended = true
            self.chunk = None
            return Ok(Some(DataEnd))
          }
          Ok(Some(record)) => return Ok(Some(record))
          Ok(None) => ()
          Err(message) => return Err(message)
        }
      }
      Some(_) => {
        self.chunk = None
        self.chunk_offset = 0
      }
      None => {
        let (opcode, payload) = match read_raw_record(self.source) {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        if opcode == 0x06 {
          self.chunk = match parse_chunk(payload) {
            Ok(value) => Some(value)
            Err(message) => return Err(message)
          }
          self.chunk_offset = 0
          continue
        }
        match parse_record(opcode, payload) {
          Ok(Some(DataEnd)) => {
            self.ended = true
            return Ok(Some(DataEnd))
          }
          Ok(Some(record)) => return Ok(Some(record))
          Ok(None) => ()
          Err(message) => return Err(message)
        }
      }
    }
  } nobreak {
    Err("MCAP reader stopped unexpectedly")
  }
}
