///|
/// The RTPS SequenceNumber_t value used by DDS for an unknown sequence.
pub const SAMPLE_IDENTITY_UNKNOWN_SEQUENCE : Int64 = -4294967296L

///|
/// The RTPS sample identity used to correlate a DDS-RPC reply with a request.
pub struct SampleIdentity {
  writer_guid : Guid
  sequence_number : Int64
} derive(Eq, Debug)

///|
pub fn SampleIdentity::new(
  writer_guid : Guid,
  sequence_number : Int64,
) -> Result[SampleIdentity, String] {
  if sequence_number == 0L ||
    (sequence_number < 0L &&
      sequence_number != SAMPLE_IDENTITY_UNKNOWN_SEQUENCE) {
    return Err("an RTPS sample identity sequence number is invalid")
  }
  Ok({ writer_guid, sequence_number, })
}

///|
/// Create the unknown-sequence identity used by ROS 2 service requests.
pub fn SampleIdentity::unknown_sequence(writer_guid : Guid) -> SampleIdentity {
  {
    writer_guid,
    sequence_number: SAMPLE_IDENTITY_UNKNOWN_SEQUENCE,
  }
}

///|
pub fn SampleIdentity::writer_guid(self : SampleIdentity) -> Guid {
  self.writer_guid
}

///|
pub fn SampleIdentity::sequence_number(self : SampleIdentity) -> Int64 {
  self.sequence_number
}

///|
/// Serialize the CDR little-endian SampleIdentity value without an
/// encapsulation header. This is the representation required by the RTPS
/// inline-QoS parameter PID_RELATED_SAMPLE_IDENTITY.
pub fn SampleIdentity::to_bytes(self : SampleIdentity) -> Bytes {
  let bytes : Array[Byte] = []
  let guid = self.writer_guid.to_bytes()
  for i in 0..<guid.length() {
    bytes.push(guid[i])
  }
  let value = self.sequence_number.reinterpret_as_uint64()
  let high = value >> 32
  let low = value & 0xFFFFFFFFL.reinterpret_as_uint64()
  bytes.push(high.to_byte())
  bytes.push((high >> 8).to_byte())
  bytes.push((high >> 16).to_byte())
  bytes.push((high >> 24).to_byte())
  bytes.push(low.to_byte())
  bytes.push((low >> 8).to_byte())
  bytes.push((low >> 16).to_byte())
  bytes.push((low >> 24).to_byte())
  Bytes::from_array(bytes)
}

///|
/// Parse a CDR little-endian SampleIdentity value without an encapsulation
/// header.
pub fn SampleIdentity::from_bytes(
  input : Bytes,
) -> Result[SampleIdentity, String] {
  SampleIdentity::from_bytes_with_endianness(input, true)
}

///|
fn SampleIdentity::from_bytes_with_endianness(
  input : Bytes,
  little_endian : Bool,
) -> Result[SampleIdentity, String] {
  if input.length() != 24 {
    return Err("an RTPS sample identity is 24 bytes")
  }
  let writer_guid = match Guid::from_bytes(bytes_from(input, 0, 16)) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let high = sample_identity_read_u32(input, 16, little_endian)
  let low = sample_identity_read_u32(input, 20, little_endian)
  let sequence_number = ((high.to_uint64() << 32) | low.to_uint64()).reinterpret_as_int64()
  SampleIdentity::new(writer_guid, sequence_number)
}

///|
fn sample_identity_read_u32(
  input : Bytes,
  offset : Int,
  little_endian : Bool,
) -> UInt {
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
