///|
/// RTPS HEARTBEAT submessage flag indicating little-endian fields.
pub const HEARTBEAT_FLAG_LITTLE_ENDIAN : Byte = 0x01

///|
/// RTPS HEARTBEAT flag indicating that no immediate ACKNACK is required.
pub const HEARTBEAT_FLAG_FINAL : Byte = 0x02

///|
/// RTPS ACKNACK submessage flag indicating little-endian fields.
pub const ACKNACK_FLAG_LITTLE_ENDIAN : Byte = 0x01

///|
/// RTPS ACKNACK flag indicating that no further response is currently needed.
pub const ACKNACK_FLAG_FINAL : Byte = 0x02

///|
/// The RTPS HEARTBEAT body has two EntityIds, two SequenceNumbers, and Count.
pub const HEARTBEAT_BODY_LENGTH : Int = 28

///|
/// A decoded RTPS HEARTBEAT submessage.
pub struct HeartbeatSubmessage {
  flags : Byte
  reader_id : EntityId
  writer_id : EntityId
  first_sequence_number : Int64
  last_sequence_number : Int64
  count : UInt
} derive(Eq, Debug)

///|
/// Create a little-endian HEARTBEAT with a valid available sequence range.
pub fn HeartbeatSubmessage::new(
  reader_id : EntityId,
  writer_id : EntityId,
  first_sequence_number : Int64,
  last_sequence_number : Int64,
  count : UInt,
) -> Result[HeartbeatSubmessage, String] {
  if first_sequence_number < 1L || last_sequence_number < first_sequence_number {
    return Err("an RTPS HEARTBEAT sequence range is invalid")
  }
  Ok({
    flags: HEARTBEAT_FLAG_LITTLE_ENDIAN,
    reader_id,
    writer_id,
    first_sequence_number,
    last_sequence_number,
    count,
  })
}

///|
/// Mark a HEARTBEAT as final.
pub fn HeartbeatSubmessage::with_final(
  self : HeartbeatSubmessage,
) -> HeartbeatSubmessage {
  { ..self, flags: self.flags | HEARTBEAT_FLAG_FINAL, }
}

///|
pub fn HeartbeatSubmessage::flags(self : HeartbeatSubmessage) -> Byte {
  self.flags
}

///|
pub fn HeartbeatSubmessage::reader_id(self : HeartbeatSubmessage) -> EntityId {
  self.reader_id
}

///|
pub fn HeartbeatSubmessage::writer_id(self : HeartbeatSubmessage) -> EntityId {
  self.writer_id
}

///|
pub fn HeartbeatSubmessage::first_sequence_number(
  self : HeartbeatSubmessage,
) -> Int64 {
  self.first_sequence_number
}

///|
pub fn HeartbeatSubmessage::last_sequence_number(
  self : HeartbeatSubmessage,
) -> Int64 {
  self.last_sequence_number
}

///|
pub fn HeartbeatSubmessage::count(self : HeartbeatSubmessage) -> UInt {
  self.count
}

///|
/// A decoded RTPS ACKNACK submessage and its missing-sequence bitmap.
pub struct AckNackSubmessage {
  flags : Byte
  reader_id : EntityId
  writer_id : EntityId
  bitmap_base : Int64
  num_bits : UInt
  bitmap : Array[UInt]
  count : UInt
} derive(Eq, Debug)

///|
/// Create a little-endian ACKNACK with an RTPS SequenceNumberSet bitmap.
pub fn AckNackSubmessage::new(
  reader_id : EntityId,
  writer_id : EntityId,
  bitmap_base : Int64,
  num_bits : UInt,
  bitmap : Array[UInt],
  count : UInt,
) -> Result[AckNackSubmessage, String] {
  if bitmap_base < 1L {
    return Err("an RTPS ACKNACK bitmap base must be positive")
  }
  if num_bits > 256U {
    return Err("an RTPS ACKNACK bitmap cannot exceed 256 bits")
  }
  let expected_words = (num_bits.reinterpret_as_int() + 31) / 32
  if bitmap.length() != expected_words {
    return Err("an RTPS ACKNACK bitmap has the wrong number of words")
  }
  Ok({
    flags: ACKNACK_FLAG_LITTLE_ENDIAN,
    reader_id,
    writer_id,
    bitmap_base,
    num_bits,
    bitmap,
    count,
  })
}

///|
/// Mark an ACKNACK as final.
pub fn AckNackSubmessage::with_final(
  self : AckNackSubmessage,
) -> AckNackSubmessage {
  { ..self, flags: self.flags | ACKNACK_FLAG_FINAL, }
}

///|
pub fn AckNackSubmessage::flags(self : AckNackSubmessage) -> Byte {
  self.flags
}

///|
pub fn AckNackSubmessage::reader_id(self : AckNackSubmessage) -> EntityId {
  self.reader_id
}

///|
pub fn AckNackSubmessage::writer_id(self : AckNackSubmessage) -> EntityId {
  self.writer_id
}

///|
pub fn AckNackSubmessage::bitmap_base(self : AckNackSubmessage) -> Int64 {
  self.bitmap_base
}

///|
pub fn AckNackSubmessage::num_bits(self : AckNackSubmessage) -> UInt {
  self.num_bits
}

///|
pub fn AckNackSubmessage::bitmap(self : AckNackSubmessage) -> Array[UInt] {
  self.bitmap
}

///|
pub fn AckNackSubmessage::count(self : AckNackSubmessage) -> UInt {
  self.count
}

///|
fn reliability_append_u32(bytes : Array[Byte], value : UInt) -> Unit {
  bytes.push(value.to_byte())
  bytes.push((value >> 8).to_byte())
  bytes.push((value >> 16).to_byte())
  bytes.push((value >> 24).to_byte())
}

///|
fn reliability_append_i64(bytes : Array[Byte], value : Int64) -> Unit {
  let encoded = value.reinterpret_as_uint64()
  bytes.push(encoded.to_byte())
  bytes.push((encoded >> 8).to_byte())
  bytes.push((encoded >> 16).to_byte())
  bytes.push((encoded >> 24).to_byte())
  bytes.push((encoded >> 32).to_byte())
  bytes.push((encoded >> 40).to_byte())
  bytes.push((encoded >> 48).to_byte())
  bytes.push((encoded >> 56).to_byte())
}

///|
fn reliability_read_u32(input : Bytes, offset : Int) -> UInt {
  input[offset].to_int().reinterpret_as_uint() |
  (input[offset + 1].to_int().reinterpret_as_uint() << 8) |
  (input[offset + 2].to_int().reinterpret_as_uint() << 16) |
  (input[offset + 3].to_int().reinterpret_as_uint() << 24)
}

///|
fn reliability_read_i64(input : Bytes, offset : Int) -> Int64 {
  match input[offset:offset + 8] {
    [u64le(value)] => value.reinterpret_as_int64()
    _ => 0L
  }
}

///|
/// Serialize the HEARTBEAT body without its four-byte submessage header.
pub fn HeartbeatSubmessage::to_payload(self : HeartbeatSubmessage) -> Bytes {
  let bytes : Array[Byte] = []
  let reader_id = self.reader_id.to_bytes()
  let writer_id = self.writer_id.to_bytes()
  for i in 0..<4 {
    bytes.push(reader_id[i])
  }
  for i in 0..<4 {
    bytes.push(writer_id[i])
  }
  reliability_append_i64(bytes, self.first_sequence_number)
  reliability_append_i64(bytes, self.last_sequence_number)
  reliability_append_u32(bytes, self.count)
  Bytes::from_array(bytes)
}

///|
/// Wrap the HEARTBEAT body in an RTPS submessage.
pub fn HeartbeatSubmessage::to_submessage(
  self : HeartbeatSubmessage,
) -> Submessage {
  Submessage::new(SubmessageId::Heartbeat, self.flags, self.to_payload())
}

///|
/// Build an RTPS message containing this HEARTBEAT.
pub fn HeartbeatSubmessage::to_message(
  self : HeartbeatSubmessage,
  guid_prefix : GuidPrefix,
  vendor_id : VendorId,
) -> Message {
  let message = Message::new(Header::new(guid_prefix, vendor_id))
  message.add(self.to_submessage())
  message
}

///|
/// Parse a HEARTBEAT submessage.
pub fn HeartbeatSubmessage::from_submessage(
  submessage : Submessage,
) -> Result[HeartbeatSubmessage, String] {
  if submessage.id() != SubmessageId::Heartbeat {
    return Err("expected an RTPS HEARTBEAT submessage")
  }
  if (submessage.flags() & HEARTBEAT_FLAG_LITTLE_ENDIAN) == 0 {
    return Err("only little-endian RTPS HEARTBEAT is supported")
  }
  if submessage.payload.length() != HEARTBEAT_BODY_LENGTH {
    return Err("an RTPS HEARTBEAT body must be 28 bytes")
  }
  let reader_id = match
    EntityId::from_bytes(bytes_from(submessage.payload, 0, 4)) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let writer_id = match
    EntityId::from_bytes(bytes_from(submessage.payload, 4, 4)) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let first_sequence_number = reliability_read_i64(submessage.payload, 8)
  let last_sequence_number = reliability_read_i64(submessage.payload, 16)
  let count = reliability_read_u32(submessage.payload, 24)
  let result = match
    HeartbeatSubmessage::new(
      reader_id, writer_id, first_sequence_number, last_sequence_number, count,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ ..result, flags: submessage.flags(), })
}

///|
/// Serialize the ACKNACK body without its four-byte submessage header.
pub fn AckNackSubmessage::to_payload(self : AckNackSubmessage) -> Bytes {
  let bytes : Array[Byte] = []
  let reader_id = self.reader_id.to_bytes()
  let writer_id = self.writer_id.to_bytes()
  for i in 0..<4 {
    bytes.push(reader_id[i])
  }
  for i in 0..<4 {
    bytes.push(writer_id[i])
  }
  reliability_append_i64(bytes, self.bitmap_base)
  reliability_append_u32(bytes, self.num_bits)
  for word in self.bitmap {
    reliability_append_u32(bytes, word)
  }
  reliability_append_u32(bytes, self.count)
  Bytes::from_array(bytes)
}

///|
/// Wrap the ACKNACK body in an RTPS submessage.
pub fn AckNackSubmessage::to_submessage(self : AckNackSubmessage) -> Submessage {
  Submessage::new(SubmessageId::AckNack, self.flags, self.to_payload())
}

///|
/// Build an RTPS message containing this ACKNACK.
pub fn AckNackSubmessage::to_message(
  self : AckNackSubmessage,
  guid_prefix : GuidPrefix,
  vendor_id : VendorId,
) -> Message {
  let message = Message::new(Header::new(guid_prefix, vendor_id))
  message.add(self.to_submessage())
  message
}

///|
/// Parse an ACKNACK submessage.
pub fn AckNackSubmessage::from_submessage(
  submessage : Submessage,
) -> Result[AckNackSubmessage, String] {
  if submessage.id() != SubmessageId::AckNack {
    return Err("expected an RTPS ACKNACK submessage")
  }
  if (submessage.flags() & ACKNACK_FLAG_LITTLE_ENDIAN) == 0 {
    return Err("only little-endian RTPS ACKNACK is supported")
  }
  if submessage.payload.length() < 24 {
    return Err("an RTPS ACKNACK body is shorter than its fixed fields")
  }
  let reader_id = match
    EntityId::from_bytes(bytes_from(submessage.payload, 0, 4)) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let writer_id = match
    EntityId::from_bytes(bytes_from(submessage.payload, 4, 4)) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let bitmap_base = reliability_read_i64(submessage.payload, 8)
  let num_bits = reliability_read_u32(submessage.payload, 16)
  if num_bits > 256U {
    return Err("an RTPS ACKNACK bitmap cannot exceed 256 bits")
  }
  let word_count = (num_bits.reinterpret_as_int() + 31) / 32
  let expected_length = 24 + word_count * 4
  if submessage.payload.length() != expected_length {
    return Err("an RTPS ACKNACK body has an invalid bitmap length")
  }
  let bitmap : Array[UInt] = []
  for i in 0..<word_count {
    bitmap.push(reliability_read_u32(submessage.payload, 20 + i * 4))
  }
  let count = reliability_read_u32(submessage.payload, 20 + word_count * 4)
  let result = match
    AckNackSubmessage::new(
      reader_id, writer_id, bitmap_base, num_bits, bitmap, count,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ ..result, flags: submessage.flags(), })
}
