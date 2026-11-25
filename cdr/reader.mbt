///|
/// CDR big-endian encapsulation identifier.
pub const CDR_BE : UInt16 = 0x0000

///|
/// A cursor for reading a ROS 2 CDR payload.
pub struct Reader {
  bytes : Bytes
  mut offset : Int32
  little_endian : Bool
}

///|
/// Start reading a CDR big-endian or little-endian payload.
pub fn Reader::from_bytes(bytes : Bytes) -> Result[Reader, String] {
  if bytes.length() < ENCAPSULATION_LENGTH {
    return Err("a CDR payload must contain a 4-byte encapsulation header")
  }
  // The final two bytes are encapsulation options. Cyclone DDS sets one of
  // these option bits for otherwise ordinary little-endian CDR payloads.
  if bytes[0] != 0 || (bytes[1] != 0 && bytes[1] != 1) {
    return Err("only CDR_BE and CDR_LE encapsulations are supported")
  }
  Ok({ bytes, offset: ENCAPSULATION_LENGTH, little_endian: bytes[1] == 1, })
}

///|
#inline
fn cdr_reader_read_u16(
  input : Bytes,
  offset : Int32,
  little_endian : Bool,
) -> UInt32 {
  if little_endian {
    input[offset].to_int().reinterpret_as_uint() |
    (input[offset + 1].to_int().reinterpret_as_uint() << 8)
  } else {
    (input[offset].to_int().reinterpret_as_uint() << 8) |
    input[offset + 1].to_int().reinterpret_as_uint()
  }
}

///|
#inline
fn cdr_reader_read_u32(
  input : Bytes,
  offset : Int32,
  little_endian : Bool,
) -> UInt32 {
  if little_endian {
    input[offset].to_int().reinterpret_as_uint() |
    (input[offset + 1].to_int().reinterpret_as_uint() << 8) |
    (input[offset + 2].to_int().reinterpret_as_uint() << 16) |
    (input[offset + 3].to_int().reinterpret_as_uint() << 24)
  } else {
    (input[offset].to_int().reinterpret_as_uint() << 24) |
    (input[offset + 1].to_int().reinterpret_as_uint() << 16) |
    (input[offset + 2].to_int().reinterpret_as_uint() << 8) |
    input[offset + 3].to_int().reinterpret_as_uint()
  }
}

///|
#inline
fn cdr_reader_read_u64(
  input : Bytes,
  offset : Int32,
  little_endian : Bool,
) -> UInt64 {
  if little_endian {
    input[offset].to_int().to_uint64() |
    (input[offset + 1].to_int().to_uint64() << 8) |
    (input[offset + 2].to_int().to_uint64() << 16) |
    (input[offset + 3].to_int().to_uint64() << 24) |
    (input[offset + 4].to_int().to_uint64() << 32) |
    (input[offset + 5].to_int().to_uint64() << 40) |
    (input[offset + 6].to_int().to_uint64() << 48) |
    (input[offset + 7].to_int().to_uint64() << 56)
  } else {
    (input[offset].to_int().to_uint64() << 56) |
    (input[offset + 1].to_int().to_uint64() << 48) |
    (input[offset + 2].to_int().to_uint64() << 40) |
    (input[offset + 3].to_int().to_uint64() << 32) |
    (input[offset + 4].to_int().to_uint64() << 24) |
    (input[offset + 5].to_int().to_uint64() << 16) |
    (input[offset + 6].to_int().to_uint64() << 8) |
    input[offset + 7].to_int().to_uint64()
  }
}

///|
/// Return the number of unread bytes.
pub fn Reader::remaining(self : Reader) -> Int32 {
  self.bytes.length() - self.offset
}

///|
/// Check for the zero-filled final padding of a CDR aggregate.
pub fn Reader::remaining_is_zero_padding(
  self : Reader,
  alignment : Int32,
) -> Bool {
  let remaining = self.remaining()
  if alignment <= 0 || remaining >= alignment {
    return remaining == 0
  }
  @padding.is_zero_filled(self.bytes, self.offset, self.offset + remaining)
}

///|
// Perf: compute the aligned start without allocating an intermediate
// `Result[Unit, String]`. The CDR header is not part of the aligned stream.
#inline
fn Reader::aligned_offset(self : Reader, alignment : Int32) -> Int32 {
  let remainder = (self.offset - ENCAPSULATION_LENGTH) % alignment
  self.offset + (if remainder == 0 { 0 } else { alignment - remainder })
}

///|
/// Read an unaligned CDR octet.
// Perf: one bounds check and one `Ok` instead of `take`'s boxed byte view.
pub fn Reader::read_u8(self : Reader) -> Result[Byte, String] {
  let offset = self.offset
  if offset >= self.bytes.length() {
    return Err("truncated CDR payload")
  }
  self.offset = offset + 1
  Ok(self.bytes[offset])
}

///|
/// Read a signed CDR int8 without alignment.
pub fn Reader::read_i8(self : Reader) -> Result[Int32, String] {
  let offset = self.offset
  if offset >= self.bytes.length() {
    return Err("truncated CDR payload")
  }
  self.offset = offset + 1
  let raw = self.bytes[offset].to_int()
  Ok(if raw >= 128 { raw - 256 } else { raw })
}

///|
/// Read a CDR boolean encoded as 0 or 1.
pub fn Reader::read_bool(self : Reader) -> Result[Bool, String] {
  let offset = self.offset
  if offset >= self.bytes.length() {
    return Err("truncated CDR payload")
  }
  self.offset = offset + 1
  match self.bytes[offset] {
    0 => Ok(false)
    1 => Ok(true)
    _ => Err("invalid CDR boolean")
  }
}

///|
/// Read a signed CDR 16-bit integer.
pub fn Reader::read_i16(self : Reader) -> Result[Int32, String] {
  let start = self.aligned_offset(2)
  if start > self.bytes.length() - 2 {
    return Err("truncated CDR payload")
  }
  self.offset = start + 2
  let raw = cdr_reader_read_u16(self.bytes, start, self.little_endian).reinterpret_as_int()
  Ok(if raw >= 32768 { raw - 65536 } else { raw })
}

///|
/// Read an unsigned CDR 16-bit integer.
pub fn Reader::read_u16(self : Reader) -> Result[UInt32, String] {
  let start = self.aligned_offset(2)
  if start > self.bytes.length() - 2 {
    return Err("truncated CDR payload")
  }
  self.offset = start + 2
  Ok(cdr_reader_read_u16(self.bytes, start, self.little_endian))
}

///|
/// Read a signed CDR 32-bit integer.
pub fn Reader::read_i32(self : Reader) -> Result[Int32, String] {
  let start = self.aligned_offset(4)
  if start > self.bytes.length() - 4 {
    return Err("truncated CDR payload")
  }
  self.offset = start + 4
  Ok(
    cdr_reader_read_u32(self.bytes, start, self.little_endian).reinterpret_as_int(),
  )
}

///|
/// Read an unsigned CDR 32-bit integer.
pub fn Reader::read_u32(self : Reader) -> Result[UInt32, String] {
  let start = self.aligned_offset(4)
  if start > self.bytes.length() - 4 {
    return Err("truncated CDR payload")
  }
  self.offset = start + 4
  Ok(cdr_reader_read_u32(self.bytes, start, self.little_endian))
}

///|
/// Read a signed CDR 64-bit integer.
pub fn Reader::read_i64(self : Reader) -> Result[Int64, String] {
  let start = self.aligned_offset(8)
  if start > self.bytes.length() - 8 {
    return Err("truncated CDR payload")
  }
  self.offset = start + 8
  Ok(
    cdr_reader_read_u64(self.bytes, start, self.little_endian).reinterpret_as_int64(),
  )
}

///|
/// Read an unsigned CDR 64-bit integer.
pub fn Reader::read_u64(self : Reader) -> Result[UInt64, String] {
  let start = self.aligned_offset(8)
  if start > self.bytes.length() - 8 {
    return Err("truncated CDR payload")
  }
  self.offset = start + 8
  Ok(cdr_reader_read_u64(self.bytes, start, self.little_endian))
}

///|
/// Read an IEEE-754 single-precision value.
pub fn Reader::read_f32(self : Reader) -> Result[Float, String] {
  let start = self.aligned_offset(4)
  if start > self.bytes.length() - 4 {
    return Err("truncated CDR payload")
  }
  self.offset = start + 4
  Ok(
    Float::reinterpret_from_uint(
      cdr_reader_read_u32(self.bytes, start, self.little_endian),
    ),
  )
}

///|
/// Read an IEEE-754 double-precision value.
pub fn Reader::read_f64(self : Reader) -> Result[Double, String] {
  let start = self.aligned_offset(8)
  if start > self.bytes.length() - 8 {
    return Err("truncated CDR payload")
  }
  self.offset = start + 8
  Ok(
    cdr_reader_read_u64(self.bytes, start, self.little_endian).reinterpret_as_double(),
  )
}

///|
/// Read a fixed-size byte array.
pub fn Reader::read_byte_array(
  self : Reader,
  length : Int32,
) -> Result[Bytes, String] {
  if length < 0 || length > self.bytes.length() - self.offset {
    return Err("truncated CDR payload")
  }
  let start = self.offset
  self.offset = start + length
  Ok(self.bytes[start:start + length].to_owned())
}

///|
/// Read a fixed-size byte array into a mutable array.
// Perf: bulk-copy byte payloads instead of pushing one octet at a time.
pub fn Reader::read_byte_array_to_array(
  self : Reader,
  length : Int32,
) -> Result[Array[Byte], String] {
  if length < 0 || length > self.bytes.length() - self.offset {
    return Err("truncated CDR payload")
  }
  let start = self.offset
  self.offset = start + length
  Ok(self.bytes[start:start + length].to_array())
}

///|
/// Read a byte sequence with a CDR uint32 length prefix.
pub fn Reader::read_byte_sequence(self : Reader) -> Result[Bytes, String] {
  let start = self.aligned_offset(4)
  if start > self.bytes.length() - 4 {
    return Err("truncated CDR payload")
  }
  self.offset = start + 4
  let length = cdr_reader_read_u32(self.bytes, start, self.little_endian).reinterpret_as_int()
  self.read_byte_array(length)
}

///|
/// Read a UTF-8 CDR string and remove its terminating NUL byte.
pub fn Reader::read_string(self : Reader) -> Result[String, String] {
  let start = self.aligned_offset(4)
  if start > self.bytes.length() - 4 {
    return Err("truncated CDR payload")
  }
  self.offset = start + 4
  let length = cdr_reader_read_u32(self.bytes, start, self.little_endian).reinterpret_as_int()
  if length <= 0 {
    return Err("a CDR string length must include a terminating NUL")
  }
  if length > self.bytes.length() - self.offset {
    return Err("truncated CDR payload")
  }
  let encoded_start = self.offset
  self.offset = encoded_start + length
  if self.bytes[encoded_start + length - 1] != 0 {
    return Err("a CDR string must end with NUL")
  }
  Ok(@utf8.decode(self.bytes[encoded_start:encoded_start + length - 1])) catch {
    _ => Err("invalid UTF-8 in CDR string")
  }
}

///|
/// Read a UTF-8 CDR string and enforce its maximum number of characters.
pub fn Reader::read_bounded_string(
  self : Reader,
  maximum_length : Int32,
) -> Result[String, String] {
  if maximum_length < 0 {
    return Err("a CDR string bound must not be negative")
  }
  let value = match self.read_string() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if cdr_utf8_character_count(value) > maximum_length {
    return Err("CDR string exceeds its character bound")
  }
  Ok(value)
}

///|
/// Read a ROS wide string encoded as widened UTF-16 code units.
pub fn Reader::read_wstring(self : Reader) -> Result[String, String] {
  let start = self.aligned_offset(4)
  if start > self.bytes.length() - 4 {
    return Err("truncated CDR payload")
  }
  self.offset = start + 4
  let length = cdr_reader_read_u32(self.bytes, start, self.little_endian).reinterpret_as_int()
  if length < 0 || length > self.remaining() / 4 {
    return Err("a CDR wide string is truncated")
  }
  let encoded : Array[Byte] = []
  encoded.reserve_capacity(length)
  let mut index = 0
  while index < length {
    let first = match self.read_u32() {
      Ok(value) if value <= 0xFFFFU => value.reinterpret_as_int()
      Ok(_) => return Err("CDR wide string contains a non-UTF-16 code unit")
      Err(message) => return Err(message)
    }
    if first == 0 {
      return Err("CDR wide strings must not contain NUL")
    }
    let codepoint = if first >= 0xD800 && first <= 0xDBFF {
      if index + 1 >= length {
        return Err("CDR wide string contains an incomplete surrogate pair")
      }
      let second = match self.read_u32() {
        Ok(value) if value <= 0xFFFFU => value.reinterpret_as_int()
        Ok(_) => return Err("CDR wide string contains a non-UTF-16 code unit")
        Err(message) => return Err(message)
      }
      if second < 0xDC00 || second > 0xDFFF {
        return Err("CDR wide string contains an invalid surrogate pair")
      }
      index += 1
      0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00)
    } else if first >= 0xDC00 && first <= 0xDFFF {
      return Err("CDR wide string contains an unpaired low surrogate")
    } else {
      first
    }
    cdr_append_utf8_codepoint(encoded, codepoint)
    index += 1
  }
  Ok(@utf8.decode(Bytes::from_array(encoded))) catch {
    _ => Err("invalid UTF-16 in CDR wide string")
  }
}

///|
/// Read a UTF-16 ROS wide string and enforce its code-unit bound.
pub fn Reader::read_bounded_wstring(
  self : Reader,
  maximum_length : Int32,
) -> Result[String, String] {
  if maximum_length < 0 {
    return Err("a CDR wide-string bound must not be negative")
  }
  let value = match self.read_wstring() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let units = match cdr_utf16_code_units(value) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if units.length() > maximum_length {
    return Err("CDR wide string exceeds its code-unit bound")
  }
  Ok(value)
}

///|
fn cdr_append_utf8_codepoint(output : Array[Byte], codepoint : Int32) -> Unit {
  if codepoint <= 0x7F {
    output.push(codepoint.to_byte())
  } else if codepoint <= 0x7FF {
    output.push((0xC0 | (codepoint >> 6)).to_byte())
    output.push((0x80 | (codepoint & 0x3F)).to_byte())
  } else if codepoint <= 0xFFFF {
    output.push((0xE0 | (codepoint >> 12)).to_byte())
    output.push((0x80 | ((codepoint >> 6) & 0x3F)).to_byte())
    output.push((0x80 | (codepoint & 0x3F)).to_byte())
  } else {
    output.push((0xF0 | (codepoint >> 18)).to_byte())
    output.push((0x80 | ((codepoint >> 12) & 0x3F)).to_byte())
    output.push((0x80 | ((codepoint >> 6) & 0x3F)).to_byte())
    output.push((0x80 | (codepoint & 0x3F)).to_byte())
  }
}
