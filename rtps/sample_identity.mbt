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
  if sequence_number < -1L {
    return Err("an RTPS sample identity sequence number is invalid")
  }
  Ok({ writer_guid, sequence_number, })
}

///|
/// Create the unknown-sequence identity used by ROS 2 service requests.
pub fn SampleIdentity::unknown_sequence(writer_guid : Guid) -> SampleIdentity {
  { writer_guid, sequence_number: -1L, }
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
  bytes.push(value.to_byte())
  bytes.push((value >> 8).to_byte())
  bytes.push((value >> 16).to_byte())
  bytes.push((value >> 24).to_byte())
  bytes.push((value >> 32).to_byte())
  bytes.push((value >> 40).to_byte())
  bytes.push((value >> 48).to_byte())
  bytes.push((value >> 56).to_byte())
  Bytes::from_array(bytes)
}

///|
/// Parse a CDR little-endian SampleIdentity value without an encapsulation
/// header.
pub fn SampleIdentity::from_bytes(
  input : Bytes,
) -> Result[SampleIdentity, String] {
  if input.length() != 24 {
    return Err("an RTPS sample identity is 24 bytes")
  }
  let writer_guid = match Guid::from_bytes(bytes_from(input, 0, 16)) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let sequence_number = match input[16:24] {
    [u64le(value)] => value.reinterpret_as_int64()
    _ => return Err("an RTPS sample identity sequence number is 8 bytes")
  }
  SampleIdentity::new(writer_guid, sequence_number)
}
