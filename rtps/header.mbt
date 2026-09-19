///|
/// The fixed RTPS protocol version used by this library.
pub const PROTOCOL_VERSION_MAJOR : Byte = 2

///|
pub const PROTOCOL_VERSION_MINOR : Byte = 3

///|
/// The size of an RTPS message header in bytes.
pub const HEADER_LENGTH : Int = 20

///|
/// The size of an RTPS submessage header in bytes.
pub const SUBMESSAGE_HEADER_LENGTH : Int = 4

///|
/// The RTPS protocol version.
pub struct ProtocolVersion {
  major : Byte
  minor : Byte
} derive(Eq, Debug)

///|
/// The vendor identifier carried by an RTPS message header.
pub struct VendorId {
  major : Byte
  minor : Byte
} derive(Eq, Debug)

///|
/// The 12-byte prefix shared by all GUIDs in one DDS domain participant.
pub struct GuidPrefix {
  bytes : Bytes
} derive(Eq, Debug)

///|
/// The RTPS message header.
pub struct Header {
  protocol_version : ProtocolVersion
  vendor_id : VendorId
  guid_prefix : GuidPrefix
}

///|
pub fn ProtocolVersion::new(major : Byte, minor : Byte) -> ProtocolVersion {
  { major, minor, }
}

///|
pub fn VendorId::new(major : Byte, minor : Byte) -> VendorId {
  { major, minor, }
}

///|
pub fn GuidPrefix::new(bytes : Bytes) -> Result[GuidPrefix, String] {
  if bytes.length() != 12 {
    Err("a GUID prefix must contain exactly 12 bytes")
  } else {
    Ok({ bytes, })
  }
}

///|
pub fn GuidPrefix::from_array(
  bytes : Array[Byte],
) -> Result[GuidPrefix, String] {
  GuidPrefix::new(Bytes::from_array(bytes))
}

///|
pub fn GuidPrefix::as_bytes(self : GuidPrefix) -> Bytes {
  self.bytes
}

///|
pub fn Header::new(guid_prefix : GuidPrefix, vendor_id : VendorId) -> Header {
  {
    protocol_version: ProtocolVersion::new(
      PROTOCOL_VERSION_MAJOR,
      PROTOCOL_VERSION_MINOR,
    ),
    vendor_id,
    guid_prefix,
  }
}

///|
/// Serialize an RTPS message header in network byte order.
pub fn Header::to_bytes(self : Header) -> Bytes {
  let bytes : Array[Byte] = [b'R', b'T', b'P', b'S']
  bytes.push(self.protocol_version.major)
  bytes.push(self.protocol_version.minor)
  bytes.push(self.vendor_id.major)
  bytes.push(self.vendor_id.minor)
  let prefix = self.guid_prefix.as_bytes()
  for i in 0..<prefix.length() {
    bytes.push(prefix[i])
  }
  Bytes::from_array(bytes)
}

///|
/// Parse one RTPS message header.
pub fn Header::from_bytes(input : Bytes) -> Result[Header, String] {
  if input.length() < HEADER_LENGTH {
    return Err("an RTPS header is 20 bytes")
  }
  if input[0] != b'R' ||
    input[1] != b'T' ||
    input[2] != b'P' ||
    input[3] != b'S' {
    return Err("invalid RTPS magic")
  }
  let prefix_bytes : Array[Byte] = []
  for i in 0..<12 {
    prefix_bytes.push(input[8 + i])
  }
  let prefix = match GuidPrefix::from_array(prefix_bytes) {
    Ok(prefix) => prefix
    Err(message) => return Err(message)
  }
  Ok({
    protocol_version: ProtocolVersion::new(input[4], input[5]),
    vendor_id: VendorId::new(input[6], input[7]),
    guid_prefix: prefix,
  })
}

///|
/// The RTPS submessage identifiers defined by the core protocol.
pub(all) enum SubmessageId {
  InfoTimestamp
  InfoDestination
  AckNack
  Heartbeat
  Gap
  InfoReply
  Data
  NackFrag
  HeartbeatFrag
  DataFrag
} derive(Eq, Debug)

///|
pub fn SubmessageId::to_byte(self : SubmessageId) -> Byte {
  match self {
    InfoTimestamp => 0x09
    InfoDestination => 0x0E
    AckNack => 0x06
    Heartbeat => 0x07
    Gap => 0x08
    InfoReply => 0x0F
    Data => 0x15
    NackFrag => 0x12
    HeartbeatFrag => 0x13
    DataFrag => 0x16
  }
}

///|
pub fn SubmessageId::from_byte(value : Byte) -> Result[SubmessageId, String] {
  match value {
    0x09 => Ok(InfoTimestamp)
    0x0E => Ok(InfoDestination)
    0x06 => Ok(AckNack)
    0x07 => Ok(Heartbeat)
    0x08 => Ok(Gap)
    0x0F => Ok(InfoReply)
    0x15 => Ok(Data)
    0x12 => Ok(NackFrag)
    0x13 => Ok(HeartbeatFrag)
    0x16 => Ok(DataFrag)
    _ => Err("unsupported RTPS submessage identifier")
  }
}

///|
/// A raw RTPS submessage. The payload is kept opaque until its type is implemented.
pub struct Submessage {
  id : SubmessageId
  flags : Byte
  payload : Bytes
} derive(Eq, Debug)

///|
pub fn Submessage::new(
  id : SubmessageId,
  flags : Byte,
  payload : Bytes,
) -> Submessage {
  { id, flags, payload, }
}

///|
/// Return a copy with the RTPS little-endian flag set.
pub fn Submessage::little_endian(self : Submessage) -> Submessage {
  { ..self, flags: self.flags | 0x01, }
}

///|
/// Serialize an RTPS submessage header followed by its opaque payload.
pub fn Submessage::to_bytes(self : Submessage) -> Result[Bytes, String] {
  if self.payload.length() > 0xFFFF {
    return Err("an RTPS submessage payload cannot exceed 65535 bytes")
  }
  let length = self.payload.length()
  let bytes : Array[Byte] = [
    self.id.to_byte(),
    self.flags,
    (length & 0xFF).to_byte(),
    ((length >> 8) & 0xFF).to_byte(),
  ]
  for i in 0..<length {
    bytes.push(self.payload[i])
  }
  Ok(Bytes::from_array(bytes))
}

///|
fn bytes_from(input : Bytes, start : Int, length : Int) -> Bytes {
  let bytes : Array[Byte] = []
  for i in 0..<length {
    bytes.push(input[start + i])
  }
  Bytes::from_array(bytes)
}

///|
/// Parse the first RTPS submessage in an input buffer.
pub fn Submessage::from_bytes(
  input : Bytes,
) -> Result[(Submessage, Int), String] {
  if input.length() < SUBMESSAGE_HEADER_LENGTH {
    return Err("an RTPS submessage header is 4 bytes")
  }
  let id = match SubmessageId::from_byte(input[0]) {
    Ok(id) => id
    Err(message) => return Err(message)
  }
  let payload_length = input[2].to_int() | (input[3].to_int() << 8)
  let total_length = SUBMESSAGE_HEADER_LENGTH + payload_length
  if input.length() < total_length {
    return Err("truncated RTPS submessage payload")
  }
  Ok(
    (
      {
        id,
        flags: input[1],
        payload: bytes_from(input, SUBMESSAGE_HEADER_LENGTH, payload_length),
      },
      total_length,
    ),
  )
}
