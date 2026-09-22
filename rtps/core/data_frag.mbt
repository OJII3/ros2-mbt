///|
/// The fixed DATA_FRAG submessage body before inline QoS or fragment data.
pub const DATA_FRAG_FIXED_BODY_LENGTH : Int = 32

///|
/// The DATA_FRAG offset from the octetsToInlineQos field to the next body element.
pub const DATA_FRAG_INLINE_QOS_OFFSET : Int = DATA_FRAG_FIXED_BODY_LENGTH - 4

///|
/// A decoded RTPS DATA_FRAG submessage.
pub struct DataFragSubmessage {
  flags : Byte
  extra_flags : UInt16
  octets_to_inline_qos : UInt16
  reader_id : EntityId
  writer_id : EntityId
  writer_sequence_number : Int64
  fragment_starting_number : UInt
  fragments_in_submessage : UInt16
  fragment_size : UInt16
  sample_size : UInt
  inline_qos : Bytes
  serialized_payload : Bytes
} derive(Eq, Debug)

///|
pub extend DataFragSubmessage with Eq::{not_equal, equal}

///|
pub extend DataFragSubmessage with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Create a little-endian DATA_FRAG carrying one or more sample fragments.
pub fn DataFragSubmessage::new(
  reader_id : EntityId,
  writer_id : EntityId,
  writer_sequence_number : Int64,
  fragment_starting_number : UInt,
  fragments_in_submessage : UInt16,
  fragment_size : UInt16,
  sample_size : UInt,
  serialized_payload : Bytes,
) -> Result[DataFragSubmessage, String] {
  if writer_sequence_number < 1L || fragment_starting_number < 1U {
    return Err("an RTPS DATA_FRAG sequence number must be positive")
  }
  if fragments_in_submessage == (0 : UInt16) ||
    fragment_size == (0 : UInt16) ||
    sample_size == 0U {
    return Err("an RTPS DATA_FRAG fragment size must be positive")
  }
  let fragment_size_int = fragment_size.to_int()
  let fragments_count = fragments_in_submessage.to_int()
  let sample_size_int = sample_size.reinterpret_as_int()
  let starting_int = fragment_starting_number.reinterpret_as_int()
  let total_fragments = (sample_size_int + fragment_size_int - 1) /
    fragment_size_int
  let last_fragment = starting_int + fragments_count - 1
  if last_fragment > total_fragments {
    return Err("an RTPS DATA_FRAG range exceeds sampleSize")
  }
  let payload_length = serialized_payload.length()
  let max_payload_length = fragment_size_int * fragments_count
  let payload_offset = (starting_int - 1) * fragment_size_int
  if payload_length == 0 ||
    payload_length > max_payload_length ||
    payload_offset + payload_length > sample_size_int {
    return Err("an RTPS DATA_FRAG payload has an invalid length")
  }
  if payload_length < max_payload_length &&
    (
      last_fragment != total_fragments ||
      payload_length != sample_size_int - payload_offset
    ) {
    return Err("only the final RTPS DATA_FRAG may be short")
  }
  Ok({
    flags: DATA_FLAG_LITTLE_ENDIAN | DATA_FLAG_DATA,
    extra_flags: 0,
    octets_to_inline_qos: DATA_FRAG_INLINE_QOS_OFFSET.to_uint16(),
    reader_id,
    writer_id,
    writer_sequence_number,
    fragment_starting_number,
    fragments_in_submessage,
    fragment_size,
    sample_size,
    inline_qos: b"",
    serialized_payload,
  })
}

///|
/// Return a copy carrying an RTPS inline QoS parameter list.
pub fn DataFragSubmessage::with_inline_qos(
  self : DataFragSubmessage,
  inline_qos : Bytes,
) -> DataFragSubmessage {
  {
    ..self,
    flags: self.flags | DATA_FLAG_INLINE_QOS,
    octets_to_inline_qos: DATA_FRAG_INLINE_QOS_OFFSET.to_uint16(),
    inline_qos,
  }
}

///|
pub fn DataFragSubmessage::flags(self : DataFragSubmessage) -> Byte {
  self.flags
}

///|
pub fn DataFragSubmessage::reader_id(self : DataFragSubmessage) -> EntityId {
  self.reader_id
}

///|
pub fn DataFragSubmessage::writer_id(self : DataFragSubmessage) -> EntityId {
  self.writer_id
}

///|
pub fn DataFragSubmessage::writer_sequence_number(
  self : DataFragSubmessage,
) -> Int64 {
  self.writer_sequence_number
}

///|
pub fn DataFragSubmessage::fragment_starting_number(
  self : DataFragSubmessage,
) -> UInt {
  self.fragment_starting_number
}

///|
pub fn DataFragSubmessage::fragments_in_submessage(
  self : DataFragSubmessage,
) -> UInt16 {
  self.fragments_in_submessage
}

///|
pub fn DataFragSubmessage::fragment_size(self : DataFragSubmessage) -> UInt16 {
  self.fragment_size
}

///|
pub fn DataFragSubmessage::sample_size(self : DataFragSubmessage) -> UInt {
  self.sample_size
}

///|
pub fn DataFragSubmessage::inline_qos(self : DataFragSubmessage) -> Bytes {
  self.inline_qos
}

///|
pub fn DataFragSubmessage::serialized_payload(
  self : DataFragSubmessage,
) -> Bytes {
  self.serialized_payload
}

///|
/// Serialize the DATA_FRAG body without its four-byte submessage header.
pub fn DataFragSubmessage::to_payload(self : DataFragSubmessage) -> Bytes {
  let bytes : Array[Byte] = []
  data_append_u16_le(bytes, self.extra_flags)
  data_append_u16_le(bytes, self.octets_to_inline_qos)
  let reader_id = self.reader_id.to_bytes()
  let writer_id = self.writer_id.to_bytes()
  for i in 0..<4 {
    bytes.push(reader_id[i])
  }
  for i in 0..<4 {
    bytes.push(writer_id[i])
  }
  append_sequence_number_le(bytes, self.writer_sequence_number)
  data_append_u32_le(bytes, self.fragment_starting_number)
  data_append_u16_le(bytes, self.fragments_in_submessage)
  data_append_u16_le(bytes, self.fragment_size)
  data_append_u32_le(bytes, self.sample_size)
  for i in 0..<self.inline_qos.length() {
    bytes.push(self.inline_qos[i])
  }
  for i in 0..<self.serialized_payload.length() {
    bytes.push(self.serialized_payload[i])
  }
  Bytes::from_array(bytes)
}

///|
/// Wrap the DATA_FRAG body in an RTPS submessage.
pub fn DataFragSubmessage::to_submessage(
  self : DataFragSubmessage,
) -> Submessage {
  Submessage::new(DataFrag, self.flags, self.to_payload())
}

///|
/// Build an RTPS message containing this DATA_FRAG.
pub fn DataFragSubmessage::to_message(
  self : DataFragSubmessage,
  guid_prefix : GuidPrefix,
  vendor_id : VendorId,
) -> Message {
  let message = Message::new(Header::new(guid_prefix, vendor_id))
  message.add(self.to_submessage())
  message
}

///|
/// Parse a DATA_FRAG submessage.
pub fn DataFragSubmessage::from_submessage(
  submessage : Submessage,
) -> Result[DataFragSubmessage, String] {
  if submessage.id() != DataFrag {
    return Err("expected an RTPS DATA_FRAG submessage")
  }
  if submessage.payload.length() < DATA_FRAG_FIXED_BODY_LENGTH {
    return Err("an RTPS DATA_FRAG body is shorter than its fixed fields")
  }
  let little_endian = (submessage.flags() & DATA_FLAG_LITTLE_ENDIAN) != 0
  let extra_flags = data_read_u16(submessage.payload, 0, little_endian)
  let octets_to_inline_qos = data_read_u16(submessage.payload, 2, little_endian)
  let reader_id = match
    EntityId::from_bytes(bytes_from(submessage.payload, 4, 4)) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let writer_id = match
    EntityId::from_bytes(bytes_from(submessage.payload, 8, 4)) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let sequence_number = read_sequence_number(
    submessage.payload,
    12,
    little_endian,
  )
  let fragment_starting_number = data_read_u32(
    submessage.payload,
    20,
    little_endian,
  )
  let fragments_in_submessage = data_read_u16(
    submessage.payload,
    24,
    little_endian,
  )
  let fragment_size = data_read_u16(submessage.payload, 26, little_endian)
  let sample_size = data_read_u32(submessage.payload, 28, little_endian)
  if octets_to_inline_qos.to_int() < DATA_FRAG_INLINE_QOS_OFFSET {
    return Err("RTPS DATA_FRAG octetsToInlineQos is too small")
  }
  let inline_qos_offset = 4 + octets_to_inline_qos.to_int()
  if inline_qos_offset > submessage.payload.length() {
    return Err("RTPS DATA_FRAG octetsToInlineQos points outside the body")
  }
  let mut inline_qos = b""
  let mut payload_offset = inline_qos_offset
  if (submessage.flags() & DATA_FLAG_INLINE_QOS) != 0 {
    let remaining = bytes_from(
      submessage.payload,
      inline_qos_offset,
      submessage.payload.length() - inline_qos_offset,
    )
    let (decoded_inline_qos, consumed) = match
      data_inline_qos_from_bytes(remaining, little_endian) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    inline_qos = decoded_inline_qos
    payload_offset = inline_qos_offset + consumed
  }
  let data_and_key_flags = submessage.flags() & (DATA_FLAG_DATA | DATA_FLAG_KEY)
  if data_and_key_flags == 0 ||
    data_and_key_flags == (DATA_FLAG_DATA | DATA_FLAG_KEY) {
    return Err("RTPS DATA_FRAG must contain exactly one data or key flag")
  }
  let result = match
    DataFragSubmessage::new(
      reader_id,
      writer_id,
      sequence_number,
      fragment_starting_number,
      fragments_in_submessage,
      fragment_size,
      sample_size,
      bytes_from(
        submessage.payload,
        payload_offset,
        submessage.payload.length() - payload_offset,
      ),
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({
    ..result,
    flags: submessage.flags() | DATA_FLAG_LITTLE_ENDIAN,
    extra_flags,
    octets_to_inline_qos,
    inline_qos,
  })
}
