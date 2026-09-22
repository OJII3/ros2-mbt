///|
/// INFO_TS submessage flag indicating little-endian fields.
pub const INFO_TIMESTAMP_FLAG_LITTLE_ENDIAN : Byte = 0x01

///|
/// INFO_TS submessage flag indicating that the timestamp is invalid.
pub const INFO_TIMESTAMP_FLAG_INVALIDATE : Byte = 0x02

///|
/// The RTPS INFO_TS timestamp carried in NTP seconds and fractional seconds.
pub struct InfoTimestampSubmessage {
  flags : Byte
  seconds : Int
  fraction : UInt
  valid : Bool
} derive(Eq, Debug)

///|
/// Create a little-endian INFO_TS with a valid timestamp.
pub fn InfoTimestampSubmessage::new(
  seconds : Int,
  fraction : UInt,
) -> InfoTimestampSubmessage {
  { flags: INFO_TIMESTAMP_FLAG_LITTLE_ENDIAN, seconds, fraction, valid: true, }
}

///|
/// Create a little-endian INFO_TS that invalidates the current timestamp.
pub fn InfoTimestampSubmessage::invalid() -> InfoTimestampSubmessage {
  {
    flags: INFO_TIMESTAMP_FLAG_LITTLE_ENDIAN | INFO_TIMESTAMP_FLAG_INVALIDATE,
    seconds: 0,
    fraction: 0,
    valid: false,
  }
}

///|
pub fn InfoTimestampSubmessage::flags(self : InfoTimestampSubmessage) -> Byte {
  self.flags
}

///|
pub fn InfoTimestampSubmessage::seconds(self : InfoTimestampSubmessage) -> Int {
  self.seconds
}

///|
pub fn InfoTimestampSubmessage::fraction(
  self : InfoTimestampSubmessage,
) -> UInt {
  self.fraction
}

///|
pub fn InfoTimestampSubmessage::is_valid(
  self : InfoTimestampSubmessage,
) -> Bool {
  self.valid
}

///|
fn info_timestamp_append_u32(
  bytes : Array[Byte],
  value : UInt,
  little_endian : Bool,
) -> Unit {
  if little_endian {
    bytes.push(value.to_byte())
    bytes.push((value >> 8).to_byte())
    bytes.push((value >> 16).to_byte())
    bytes.push((value >> 24).to_byte())
  } else {
    bytes.push((value >> 24).to_byte())
    bytes.push((value >> 16).to_byte())
    bytes.push((value >> 8).to_byte())
    bytes.push(value.to_byte())
  }
}

///|
fn info_timestamp_read_u32(
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

///|
/// Serialize the INFO_TS body without its four-byte submessage header.
pub fn InfoTimestampSubmessage::to_payload(
  self : InfoTimestampSubmessage,
) -> Bytes {
  if !self.valid {
    return b""
  }
  let bytes : Array[Byte] = []
  let little_endian = (self.flags & INFO_TIMESTAMP_FLAG_LITTLE_ENDIAN) != 0
  info_timestamp_append_u32(
    bytes,
    self.seconds.reinterpret_as_uint(),
    little_endian,
  )
  info_timestamp_append_u32(bytes, self.fraction, little_endian)
  Bytes::from_array(bytes)
}

///|
/// Wrap this timestamp in an RTPS INFO_TS submessage.
pub fn InfoTimestampSubmessage::to_submessage(
  self : InfoTimestampSubmessage,
) -> Submessage {
  Submessage::new(InfoTimestamp, self.flags, self.to_payload())
}

///|
/// Build an RTPS message containing this INFO_TS submessage.
pub fn InfoTimestampSubmessage::to_message(
  self : InfoTimestampSubmessage,
  guid_prefix : GuidPrefix,
  vendor_id : VendorId,
) -> Message {
  let message = Message::new(Header::new(guid_prefix, vendor_id))
  message.add(self.to_submessage())
  message
}

///|
/// Parse an RTPS INFO_TS submessage.
pub fn InfoTimestampSubmessage::from_submessage(
  submessage : Submessage,
) -> Result[InfoTimestampSubmessage, String] {
  if submessage.id() != InfoTimestamp {
    return Err("expected an RTPS INFO_TS submessage")
  }
  let invalidate = (submessage.flags() & INFO_TIMESTAMP_FLAG_INVALIDATE) != 0
  if invalidate {
    if submessage.payload.length() != 0 {
      return Err("an invalid RTPS INFO_TS must not contain a timestamp")
    }
    return Ok({
      flags: submessage.flags(),
      seconds: 0,
      fraction: 0,
      valid: false,
    })
  }
  if submessage.payload.length() != 8 {
    return Err("a valid RTPS INFO_TS timestamp must be 8 bytes")
  }
  let little_endian = (submessage.flags() & INFO_TIMESTAMP_FLAG_LITTLE_ENDIAN) !=
    0
  let seconds = info_timestamp_read_u32(submessage.payload, 0, little_endian).reinterpret_as_int()
  let fraction = info_timestamp_read_u32(submessage.payload, 4, little_endian)
  Ok({ flags: submessage.flags(), seconds, fraction, valid: true, })
}
