///|
/// The fixed RTPS protocol version used by this library.
pub const PROTOCOL_VERSION_MAJOR : Byte = 2

///|
/// The fixed minor component of the RTPS protocol version.
pub const PROTOCOL_VERSION_MINOR : Byte = 3

///|
/// The size of an RTPS message header in bytes.
pub const HEADER_LENGTH : Int32 = 20

///|
/// The size of an RTPS submessage header in bytes.
pub const SUBMESSAGE_HEADER_LENGTH : Int32 = 4

///|
/// RTPS submessage flag indicating little-endian fields.
pub const SUBMESSAGE_FLAG_LITTLE_ENDIAN : Byte = 0x01

///|
/// The RTPS protocol version.
#derive(Eq, Debug)
pub struct ProtocolVersion {
  major : Byte
  minor : Byte
}

///|
/// The vendor identifier carried by an RTPS message header.
#derive(Eq, Debug)
pub struct VendorId {
  major : Byte
  minor : Byte
}

///|
/// The 12-byte prefix shared by all GUIDs in one DDS domain participant.
#derive(Eq, Debug)
pub struct GuidPrefix {
  bytes : Bytes
}

///|
/// The RTPS message header.
#derive(Eq, Debug)
pub struct Header {
  protocol_version : ProtocolVersion
  vendor_id : VendorId
  guid_prefix : GuidPrefix
}

///|
/// Create an RTPS protocol version.
pub fn ProtocolVersion::new(major : Byte, minor : Byte) -> ProtocolVersion {
  { major, minor, }
}

///|
/// Create a vendor identifier.
pub fn VendorId::new(major : Byte, minor : Byte) -> VendorId {
  { major, minor, }
}

///|
/// Create a GUID prefix from its wire-format bytes.
pub fn GuidPrefix::new(bytes : Bytes) -> Result[GuidPrefix, String] {
  if bytes.length() != 12 {
    Err("a GUID prefix must contain exactly 12 bytes")
  } else {
    Ok({ bytes, })
  }
}

///|
/// Create a GUID prefix from an array of bytes.
pub fn GuidPrefix::from_array(
  bytes : Array[Byte],
) -> Result[GuidPrefix, String] {
  GuidPrefix::new(Bytes::from_array(bytes))
}

///|
/// Return the GUID prefix bytes.
pub fn GuidPrefix::as_bytes(self : GuidPrefix) -> Bytes {
  self.bytes
}

///|
/// Create an RTPS message header.
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
/// Return the participant prefix carried by this RTPS message.
pub fn Header::guid_prefix(self : Header) -> GuidPrefix {
  self.guid_prefix
}

///|
/// Serialize an RTPS message header in network byte order.
pub fn Header::to_bytes(self : Header) -> Bytes {
  let buffer = @buffer.Buffer(capacity=HEADER_LENGTH)
  buffer.write_byte(b'R')
  buffer.write_byte(b'T')
  buffer.write_byte(b'P')
  buffer.write_byte(b'S')
  buffer.write_byte(self.protocol_version.major)
  buffer.write_byte(self.protocol_version.minor)
  buffer.write_byte(self.vendor_id.major)
  buffer.write_byte(self.vendor_id.minor)
  buffer.write_bytes(self.guid_prefix.as_bytes())
  buffer.to_bytes()
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
  let prefix = match GuidPrefix::new(input[8:20].to_owned()) {
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
#derive(Eq, Debug)
pub(all) enum SubmessageId {
  Pad
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
  Unknown(Byte)
}

///|
/// Convert a submessage identifier to its wire byte.
pub fn SubmessageId::to_byte(self : SubmessageId) -> Byte {
  match self {
    Pad => 0x01
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
    Unknown(value) => value
  }
}

///|
/// Parse a submessage identifier from its wire byte.
pub fn SubmessageId::from_byte(value : Byte) -> Result[SubmessageId, String] {
  match value {
    0x01 => Ok(Pad)
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
    _ => Ok(Unknown(value))
  }
}

///|
/// A raw RTPS submessage. The payload is kept opaque until its type is implemented.
#derive(Eq, Debug)
pub struct Submessage {
  id : SubmessageId
  flags : Byte
  payload : Bytes
}

///|
pub extend ProtocolVersion with Eq::{not_equal, equal}

///|
pub extend ProtocolVersion with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend VendorId with Eq::{not_equal, equal}

///|
pub extend VendorId with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend GuidPrefix with Eq::{not_equal, equal}

///|
pub extend GuidPrefix with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Header with Eq::{not_equal, equal}

///|
pub extend Header with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend SubmessageId with Eq::{not_equal, equal}

///|
pub extend SubmessageId with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Submessage with Eq::{not_equal, equal}

///|
pub extend Submessage with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Create an opaque RTPS submessage.
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
  { ..self, flags: self.flags | SUBMESSAGE_FLAG_LITTLE_ENDIAN, }
}

///|
/// Return the submessage identifier.
pub fn Submessage::id(self : Submessage) -> SubmessageId {
  self.id
}

///|
/// Return the submessage flags.
pub fn Submessage::flags(self : Submessage) -> Byte {
  self.flags
}

///|
/// Serialize an RTPS submessage header followed by its opaque payload.
pub fn Submessage::to_bytes(self : Submessage) -> Result[Bytes, String] {
  if self.payload.length() > 0xFFFF {
    return Err("an RTPS submessage payload cannot exceed 65535 bytes")
  }
  let buffer = @buffer.Buffer(
    capacity=SUBMESSAGE_HEADER_LENGTH + self.payload.length(),
  )
  buffer.write_byte(self.id.to_byte())
  buffer.write_byte(self.flags)
  if (self.flags & SUBMESSAGE_FLAG_LITTLE_ENDIAN) != 0 {
    buffer.write_uint16_le(self.payload.length().to_uint16())
  } else {
    buffer.write_uint16_be(self.payload.length().to_uint16())
  }
  buffer.write_bytes(self.payload)
  Ok(buffer.to_bytes())
}

///|
fn bytes_from(input : Bytes, start : Int32, length : Int32) -> Bytes {
  input[start:start + length].to_owned()
}

///|
/// Parse the first RTPS submessage in an input buffer.
pub fn Submessage::from_bytes(
  input : Bytes,
) -> Result[(Submessage, Int32), String] {
  Submessage::from_bytes_at(input, 0)
}

///|
// Perf: parse at an absolute offset so a message with several submessages does
// not copy the remaining input for every one of them.
fn Submessage::from_bytes_at(
  input : Bytes,
  offset : Int32,
) -> Result[(Submessage, Int32), String] {
  if input.length() - offset < SUBMESSAGE_HEADER_LENGTH {
    return Err("an RTPS submessage header is 4 bytes")
  }
  let id = match SubmessageId::from_byte(input[offset]) {
    Ok(id) => id
    Err(message) => return Err(message)
  }
  let flags = input[offset + 1]
  let encoded_payload_length = if (flags & SUBMESSAGE_FLAG_LITTLE_ENDIAN) != 0 {
    input[offset + 2].to_int() | (input[offset + 3].to_int() << 8)
  } else {
    (input[offset + 2].to_int() << 8) | input[offset + 3].to_int()
  }
  let payload_length = if encoded_payload_length == 0 {
    match id {
      Pad | InfoTimestamp => 0
      _ => input.length() - offset - SUBMESSAGE_HEADER_LENGTH
    }
  } else {
    encoded_payload_length
  }
  let total_length = SUBMESSAGE_HEADER_LENGTH + payload_length
  if input.length() - offset < total_length {
    return Err("truncated RTPS submessage payload")
  }
  let payload_start = offset + SUBMESSAGE_HEADER_LENGTH
  Ok(
    (
      {
        id,
        flags,
        payload: input[payload_start:payload_start + payload_length].to_owned(),
      },
      total_length,
    ),
  )
}
