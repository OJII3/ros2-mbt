///|
/// DATA submessage flag indicating little-endian fields.
pub const DATA_FLAG_LITTLE_ENDIAN : Byte = 0x01

///|
/// DATA submessage flag indicating an inline QoS parameter list.
pub const DATA_FLAG_INLINE_QOS : Byte = 0x02

///|
/// DATA submessage flag indicating a serialized payload.
pub const DATA_FLAG_DATA : Byte = 0x04

///|
/// DATA submessage flag indicating a key-only payload.
pub const DATA_FLAG_KEY : Byte = 0x08

///|
/// RTPS STATUS_INFO value for a live instance.
pub const STATUS_INFO_ALIVE : UInt = 0x00000000U

///|
/// RTPS STATUS_INFO bit for a disposed instance.
pub const STATUS_INFO_DISPOSED : UInt = 0x00000001U

///|
/// RTPS STATUS_INFO bit for an unregistered instance.
pub const STATUS_INFO_UNREGISTERED : UInt = 0x00000002U

///|
/// The fixed DATA submessage body before inline QoS or serialized data.
pub const DATA_FIXED_BODY_LENGTH : Int = 20

///|
/// The DATA offset from the octetsToInlineQos field to the next body element.
pub const DATA_INLINE_QOS_OFFSET : Int = DATA_FIXED_BODY_LENGTH - 4

///|
/// The RTPS DATA submessage body used by discovery and user data.
pub struct DataSubmessage {
  flags : Byte
  extra_flags : UInt16
  octets_to_inline_qos : UInt16
  reader_id : EntityId
  writer_id : EntityId
  writer_sequence_number : Int64
  inline_qos : Bytes
  serialized_payload : Bytes
} derive(Eq, Debug)

///|
/// Create a DATA submessage carrying a serialized payload and no inline QoS.
pub fn DataSubmessage::new(
  reader_id : EntityId,
  writer_id : EntityId,
  writer_sequence_number : Int64,
  serialized_payload : Bytes,
) -> DataSubmessage {
  {
    flags: DATA_FLAG_LITTLE_ENDIAN | DATA_FLAG_DATA,
    extra_flags: 0,
    octets_to_inline_qos: DATA_INLINE_QOS_OFFSET.to_uint16(),
    reader_id,
    writer_id,
    writer_sequence_number,
    inline_qos: b"",
    serialized_payload,
  }
}

///|
/// Return a copy carrying an RTPS inline QoS parameter list.
pub fn DataSubmessage::with_inline_qos(
  self : DataSubmessage,
  inline_qos : Bytes,
) -> DataSubmessage {
  {
    ..self,
    flags: self.flags | DATA_FLAG_INLINE_QOS,
    octets_to_inline_qos: DATA_INLINE_QOS_OFFSET.to_uint16(),
    inline_qos,
  }
}

///|
fn DataSubmessage::with_inline_parameter(
  self : DataSubmessage,
  parameter : Parameter,
) -> DataSubmessage {
  let parameters = ParameterList::new()
  if self.inline_qos.length() > 0 {
    match ParameterList::from_bytes(self.inline_qos) {
      Ok((existing, _)) =>
        for existing_parameter in existing.values() {
          parameters.add(existing_parameter)
        }
      Err(_) => ()
    }
  }
  parameters.add(parameter)
  self.with_inline_qos(parameters.to_bytes())
}

///|
/// Return a copy carrying the DDS-RPC related request identity.
pub fn DataSubmessage::with_related_sample_identity(
  self : DataSubmessage,
  identity : SampleIdentity,
) -> DataSubmessage {
  self.with_inline_parameter(
    Parameter::new(PID_RELATED_SAMPLE_IDENTITY, identity.to_bytes()),
  )
}

///|
/// Return a copy carrying an RTPS instance lifecycle state.
pub fn DataSubmessage::with_status_info(
  self : DataSubmessage,
  status : UInt,
) -> DataSubmessage {
  self.with_inline_parameter(
    Parameter::new(PID_STATUS_INFO, data_u32_le(status)),
  )
}

///|
pub fn DataSubmessage::flags(self : DataSubmessage) -> Byte {
  self.flags
}

///|
pub fn DataSubmessage::reader_id(self : DataSubmessage) -> EntityId {
  self.reader_id
}

///|
pub fn DataSubmessage::writer_id(self : DataSubmessage) -> EntityId {
  self.writer_id
}

///|
pub fn DataSubmessage::writer_sequence_number(self : DataSubmessage) -> Int64 {
  self.writer_sequence_number
}

///|
pub fn DataSubmessage::inline_qos(self : DataSubmessage) -> Bytes {
  self.inline_qos
}

///|
pub fn DataSubmessage::serialized_payload(self : DataSubmessage) -> Bytes {
  self.serialized_payload
}

///|
/// Decode the related request identity from inline QoS, if present.
pub fn DataSubmessage::related_sample_identity(
  self : DataSubmessage,
) -> Result[SampleIdentity?, String] {
  if self.inline_qos.length() == 0 {
    return Ok(None)
  }
  let parameters = match ParameterList::from_bytes(self.inline_qos) {
    Ok((value, _)) => value
    Err(message) => return Err(message)
  }
  for parameter in parameters.values() {
    if parameter.id() != PID_RELATED_SAMPLE_IDENTITY {
      continue
    }
    let identity = match SampleIdentity::from_bytes(parameter.value()) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    return Ok(Some(identity))
  }
  Ok(None)
}

///|
/// Decode the optional RTPS instance lifecycle state from inline QoS.
pub fn DataSubmessage::status_info(
  self : DataSubmessage,
) -> Result[UInt?, String] {
  if self.inline_qos.length() == 0 {
    return Ok(None)
  }
  let parameters = match ParameterList::from_bytes(self.inline_qos) {
    Ok((value, _)) => value
    Err(message) => return Err(message)
  }
  for parameter in parameters.values() {
    if parameter.id() != PID_STATUS_INFO {
      continue
    }
    let value = parameter.value()
    if value.length() != 4 {
      return Err("RTPS PID_STATUS_INFO must contain 4 bytes")
    }
    return Ok(Some(data_read_u32_le(value, 0)))
  }
  Ok(None)
}

///|
/// Return the identity of this DATA sample using the RTPS message prefix.
pub fn DataSubmessage::sample_identity(
  self : DataSubmessage,
  guid_prefix : GuidPrefix,
) -> Result[SampleIdentity, String] {
  SampleIdentity::new(
    Guid::new(guid_prefix, self.writer_id),
    self.writer_sequence_number,
  )
}

///|
fn data_append_u16_le(bytes : Array[Byte], value : UInt16) -> Unit {
  let int_value = value.to_int()
  bytes.push((int_value & 0xFF).to_byte())
  bytes.push(((int_value >> 8) & 0xFF).to_byte())
}

///|
fn data_append_u32_le(bytes : Array[Byte], value : UInt) -> Unit {
  bytes.push(value.to_byte())
  bytes.push((value >> 8).to_byte())
  bytes.push((value >> 16).to_byte())
  bytes.push((value >> 24).to_byte())
}

///|
fn data_u32_le(value : UInt) -> Bytes {
  let bytes : Array[Byte] = []
  data_append_u32_le(bytes, value)
  Bytes::from_array(bytes)
}

///|
fn append_u64_le(bytes : Array[Byte], value : UInt64) -> Unit {
  bytes.push(value.to_byte())
  bytes.push((value >> 8).to_byte())
  bytes.push((value >> 16).to_byte())
  bytes.push((value >> 24).to_byte())
  bytes.push((value >> 32).to_byte())
  bytes.push((value >> 40).to_byte())
  bytes.push((value >> 48).to_byte())
  bytes.push((value >> 56).to_byte())
}

///|
fn data_read_u16_le(input : Bytes, offset : Int) -> UInt16 {
  let value = input[offset].to_int() | (input[offset + 1].to_int() << 8)
  value.to_uint16()
}

///|
fn data_read_u32_le(input : Bytes, offset : Int) -> UInt {
  input[offset].to_int().reinterpret_as_uint() |
  (input[offset + 1].to_int().reinterpret_as_uint() << 8) |
  (input[offset + 2].to_int().reinterpret_as_uint() << 16) |
  (input[offset + 3].to_int().reinterpret_as_uint() << 24)
}

///|
fn read_u64_le(input : Bytes, offset : Int) -> UInt64 {
  match input[offset:offset + 8] {
    [u64le(value)] => value
    _ => 0
  }
}

///|
/// Serialize the DATA body without its four-byte submessage header.
pub fn DataSubmessage::to_payload(self : DataSubmessage) -> Bytes {
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
  append_u64_le(bytes, self.writer_sequence_number.reinterpret_as_uint64())
  for i in 0..<self.inline_qos.length() {
    bytes.push(self.inline_qos[i])
  }
  for i in 0..<self.serialized_payload.length() {
    bytes.push(self.serialized_payload[i])
  }
  Bytes::from_array(bytes)
}

///|
/// Wrap the DATA body in an RTPS submessage.
pub fn DataSubmessage::to_submessage(self : DataSubmessage) -> Submessage {
  Submessage::new(SubmessageId::Data, self.flags, self.to_payload())
}

///|
/// Build an RTPS message containing this DATA submessage.
pub fn DataSubmessage::to_message(
  self : DataSubmessage,
  guid_prefix : GuidPrefix,
  vendor_id : VendorId,
) -> Message {
  let message = Message::new(Header::new(guid_prefix, vendor_id))
  message.add(self.to_submessage())
  message
}

///|
/// Parse a DATA submessage from an RTPS submessage.
pub fn DataSubmessage::from_submessage(
  submessage : Submessage,
) -> Result[DataSubmessage, String] {
  if submessage.id != SubmessageId::Data {
    return Err("expected an RTPS DATA submessage")
  }
  if (submessage.flags & DATA_FLAG_LITTLE_ENDIAN) == 0 {
    return Err("only little-endian RTPS DATA submessages are supported")
  }
  if submessage.payload.length() < DATA_FIXED_BODY_LENGTH {
    return Err("an RTPS DATA body is shorter than its fixed fields")
  }
  let extra_flags = data_read_u16_le(submessage.payload, 0)
  let octets_to_inline_qos = data_read_u16_le(submessage.payload, 2)
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
  let sequence_number = read_u64_le(submessage.payload, 12).reinterpret_as_int64()
  let mut inline_qos = b""
  let mut payload_offset = DATA_FIXED_BODY_LENGTH
  let inline_qos_offset = 4 + octets_to_inline_qos.to_int()
  if octets_to_inline_qos.to_int() < DATA_INLINE_QOS_OFFSET ||
    inline_qos_offset > submessage.payload.length() {
    return Err("RTPS DATA octetsToInlineQos points outside the DATA body")
  }
  if (submessage.flags & DATA_FLAG_INLINE_QOS) != 0 {
    let remaining = bytes_from(
      submessage.payload,
      inline_qos_offset,
      submessage.payload.length() - inline_qos_offset,
    )
    let consumed = match ParameterList::from_bytes(remaining) {
      Ok((_, consumed)) => consumed
      Err(message) => return Err(message)
    }
    inline_qos = bytes_from(remaining, 0, consumed)
    payload_offset = inline_qos_offset + consumed
  } else {
    payload_offset = inline_qos_offset
  }
  let data_and_key_flags = submessage.flags & (DATA_FLAG_DATA | DATA_FLAG_KEY)
  if data_and_key_flags == 0 {
    return Err("RTPS DATA must contain data or a key")
  }
  if data_and_key_flags == (DATA_FLAG_DATA | DATA_FLAG_KEY) {
    return Err("RTPS DATA cannot contain both data and key")
  }
  Ok({
    flags: submessage.flags,
    extra_flags,
    octets_to_inline_qos,
    reader_id,
    writer_id,
    writer_sequence_number: sequence_number,
    inline_qos,
    serialized_payload: bytes_from(
      submessage.payload,
      payload_offset,
      submessage.payload.length() - payload_offset,
    ),
  })
}
