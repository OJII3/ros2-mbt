///|
/// RTPS HEARTBEAT_FRAG submessage flag indicating little-endian fields.
pub const HEARTBEAT_FRAG_FLAG_LITTLE_ENDIAN : Byte = 0x01

///|
/// RTPS NACK_FRAG submessage flag indicating little-endian fields.
pub const NACK_FRAG_FLAG_LITTLE_ENDIAN : Byte = 0x01

///|
/// The fixed HEARTBEAT_FRAG body length.
pub const HEARTBEAT_FRAG_BODY_LENGTH : Int = 24

///|
/// A decoded RTPS HEARTBEAT_FRAG submessage.
pub struct HeartbeatFragSubmessage {
  flags : Byte
  reader_id : EntityId
  writer_id : EntityId
  writer_sequence_number : Int64
  last_fragment_number : UInt
  count : UInt
} derive(Eq, Debug)

///|
/// Create a little-endian HEARTBEAT_FRAG.
pub fn HeartbeatFragSubmessage::new(
  reader_id : EntityId,
  writer_id : EntityId,
  writer_sequence_number : Int64,
  last_fragment_number : UInt,
  count : UInt,
) -> Result[HeartbeatFragSubmessage, String] {
  if writer_sequence_number < 1L || last_fragment_number < 1U {
    return Err("an RTPS HEARTBEAT_FRAG sequence number must be positive")
  }
  Ok({
    flags: HEARTBEAT_FRAG_FLAG_LITTLE_ENDIAN,
    reader_id,
    writer_id,
    writer_sequence_number,
    last_fragment_number,
    count,
  })
}

///|
pub fn HeartbeatFragSubmessage::flags(self : HeartbeatFragSubmessage) -> Byte {
  self.flags
}

///|
pub fn HeartbeatFragSubmessage::reader_id(
  self : HeartbeatFragSubmessage,
) -> EntityId {
  self.reader_id
}

///|
pub fn HeartbeatFragSubmessage::writer_id(
  self : HeartbeatFragSubmessage,
) -> EntityId {
  self.writer_id
}

///|
pub fn HeartbeatFragSubmessage::writer_sequence_number(
  self : HeartbeatFragSubmessage,
) -> Int64 {
  self.writer_sequence_number
}

///|
pub fn HeartbeatFragSubmessage::last_fragment_number(
  self : HeartbeatFragSubmessage,
) -> UInt {
  self.last_fragment_number
}

///|
pub fn HeartbeatFragSubmessage::count(self : HeartbeatFragSubmessage) -> UInt {
  self.count
}

///|
/// Serialize the HEARTBEAT_FRAG body without its submessage header.
pub fn HeartbeatFragSubmessage::to_payload(
  self : HeartbeatFragSubmessage,
) -> Bytes {
  let bytes : Array[Byte] = []
  let reader_id = self.reader_id.to_bytes()
  let writer_id = self.writer_id.to_bytes()
  for i in 0..<4 {
    bytes.push(reader_id[i])
  }
  for i in 0..<4 {
    bytes.push(writer_id[i])
  }
  reliability_append_i64(bytes, self.writer_sequence_number)
  reliability_append_u32(bytes, self.last_fragment_number)
  reliability_append_u32(bytes, self.count)
  Bytes::from_array(bytes)
}

///|
pub fn HeartbeatFragSubmessage::to_submessage(
  self : HeartbeatFragSubmessage,
) -> Submessage {
  Submessage::new(SubmessageId::HeartbeatFrag, self.flags, self.to_payload())
}

///|
pub fn HeartbeatFragSubmessage::to_message(
  self : HeartbeatFragSubmessage,
  guid_prefix : GuidPrefix,
  vendor_id : VendorId,
) -> Message {
  let message = Message::new(Header::new(guid_prefix, vendor_id))
  message.add(self.to_submessage())
  message
}

///|
pub fn HeartbeatFragSubmessage::from_submessage(
  submessage : Submessage,
) -> Result[HeartbeatFragSubmessage, String] {
  if submessage.id() != SubmessageId::HeartbeatFrag {
    return Err("expected an RTPS HEARTBEAT_FRAG submessage")
  }
  if submessage.payload.length() != HEARTBEAT_FRAG_BODY_LENGTH {
    return Err("an RTPS HEARTBEAT_FRAG body must be 24 bytes")
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
  let little_endian = (submessage.flags() & HEARTBEAT_FRAG_FLAG_LITTLE_ENDIAN) !=
    0
  let result = match
    HeartbeatFragSubmessage::new(
      reader_id,
      writer_id,
      reliability_read_i64(submessage.payload, 8, little_endian),
      reliability_read_u32(submessage.payload, 16, little_endian),
      reliability_read_u32(submessage.payload, 20, little_endian),
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({
    ..result,
    flags: submessage.flags() | HEARTBEAT_FRAG_FLAG_LITTLE_ENDIAN,
  })
}

///|
/// A decoded RTPS NACK_FRAG submessage.
pub struct NackFragSubmessage {
  flags : Byte
  reader_id : EntityId
  writer_id : EntityId
  writer_sequence_number : Int64
  bitmap_base : UInt
  num_bits : UInt
  bitmap : Array[UInt]
  count : UInt
} derive(Eq, Debug)

///|
/// Create a little-endian NACK_FRAG with a FragmentNumberSet bitmap.
pub fn NackFragSubmessage::new(
  reader_id : EntityId,
  writer_id : EntityId,
  writer_sequence_number : Int64,
  bitmap_base : UInt,
  num_bits : UInt,
  bitmap : Array[UInt],
  count : UInt,
) -> Result[NackFragSubmessage, String] {
  if writer_sequence_number < 1L || bitmap_base < 1U {
    return Err("an RTPS NACK_FRAG sequence number must be positive")
  }
  if num_bits > 256U {
    return Err("an RTPS NACK_FRAG bitmap cannot exceed 256 bits")
  }
  let expected_words = (num_bits.reinterpret_as_int() + 31) / 32
  if bitmap.length() != expected_words {
    return Err("an RTPS NACK_FRAG bitmap has the wrong number of words")
  }
  Ok({
    flags: NACK_FRAG_FLAG_LITTLE_ENDIAN,
    reader_id,
    writer_id,
    writer_sequence_number,
    bitmap_base,
    num_bits,
    bitmap,
    count,
  })
}

///|
pub fn NackFragSubmessage::flags(self : NackFragSubmessage) -> Byte {
  self.flags
}

///|
pub fn NackFragSubmessage::reader_id(self : NackFragSubmessage) -> EntityId {
  self.reader_id
}

///|
pub fn NackFragSubmessage::writer_id(self : NackFragSubmessage) -> EntityId {
  self.writer_id
}

///|
pub fn NackFragSubmessage::writer_sequence_number(
  self : NackFragSubmessage,
) -> Int64 {
  self.writer_sequence_number
}

///|
pub fn NackFragSubmessage::bitmap_base(self : NackFragSubmessage) -> UInt {
  self.bitmap_base
}

///|
pub fn NackFragSubmessage::num_bits(self : NackFragSubmessage) -> UInt {
  self.num_bits
}

///|
pub fn NackFragSubmessage::bitmap(self : NackFragSubmessage) -> Array[UInt] {
  self.bitmap
}

///|
pub fn NackFragSubmessage::count(self : NackFragSubmessage) -> UInt {
  self.count
}

///|
/// Serialize the NACK_FRAG body without its submessage header.
pub fn NackFragSubmessage::to_payload(self : NackFragSubmessage) -> Bytes {
  let bytes : Array[Byte] = []
  let reader_id = self.reader_id.to_bytes()
  let writer_id = self.writer_id.to_bytes()
  for i in 0..<4 {
    bytes.push(reader_id[i])
  }
  for i in 0..<4 {
    bytes.push(writer_id[i])
  }
  reliability_append_i64(bytes, self.writer_sequence_number)
  reliability_append_u32(bytes, self.bitmap_base)
  reliability_append_u32(bytes, self.num_bits)
  for word in self.bitmap {
    reliability_append_u32(bytes, word)
  }
  reliability_append_u32(bytes, self.count)
  Bytes::from_array(bytes)
}

///|
pub fn NackFragSubmessage::to_submessage(
  self : NackFragSubmessage,
) -> Submessage {
  Submessage::new(SubmessageId::NackFrag, self.flags, self.to_payload())
}

///|
pub fn NackFragSubmessage::to_message(
  self : NackFragSubmessage,
  guid_prefix : GuidPrefix,
  vendor_id : VendorId,
) -> Message {
  let message = Message::new(Header::new(guid_prefix, vendor_id))
  message.add(self.to_submessage())
  message
}

///|
pub fn NackFragSubmessage::from_submessage(
  submessage : Submessage,
) -> Result[NackFragSubmessage, String] {
  if submessage.id() != SubmessageId::NackFrag {
    return Err("expected an RTPS NACK_FRAG submessage")
  }
  if submessage.payload.length() < 28 {
    return Err("an RTPS NACK_FRAG body is shorter than its fixed fields")
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
  let little_endian = (submessage.flags() & NACK_FRAG_FLAG_LITTLE_ENDIAN) != 0
  let writer_sequence_number = reliability_read_i64(
    submessage.payload,
    8,
    little_endian,
  )
  let bitmap_base = reliability_read_u32(submessage.payload, 16, little_endian)
  let num_bits = reliability_read_u32(submessage.payload, 20, little_endian)
  if num_bits > 256U {
    return Err("an RTPS NACK_FRAG bitmap cannot exceed 256 bits")
  }
  let word_count = (num_bits.reinterpret_as_int() + 31) / 32
  let expected_length = 28 + word_count * 4
  if submessage.payload.length() != expected_length {
    return Err("an RTPS NACK_FRAG body has an invalid bitmap length")
  }
  let bitmap : Array[UInt] = []
  for i in 0..<word_count {
    bitmap.push(
      reliability_read_u32(submessage.payload, 24 + i * 4, little_endian),
    )
  }
  let count = reliability_read_u32(
    submessage.payload,
    24 + word_count * 4,
    little_endian,
  )
  let result = match
    NackFragSubmessage::new(
      reader_id, writer_id, writer_sequence_number, bitmap_base, num_bits, bitmap,
      count,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ ..result, flags: submessage.flags() | NACK_FRAG_FLAG_LITTLE_ENDIAN, })
}
