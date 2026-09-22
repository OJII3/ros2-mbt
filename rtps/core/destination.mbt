///|
/// INFO_DST submessage flag used for the little-endian RTPS encoding.
pub const INFO_DESTINATION_FLAG_LITTLE_ENDIAN : Byte = 0x01

///|
/// RTPS INFO_DST carrying the destination participant GUID prefix.
pub struct InfoDestinationSubmessage {
  flags : Byte
  guid_prefix : GuidPrefix
} derive(Eq, Debug)

///|
pub extend InfoDestinationSubmessage with Eq::{not_equal, equal}

///|
pub extend InfoDestinationSubmessage with @moonbitlang/core/debug.Debug::{
  to_repr,
}

///|
/// Create a little-endian INFO_DST submessage.
pub fn InfoDestinationSubmessage::new(
  guid_prefix : GuidPrefix,
) -> InfoDestinationSubmessage {
  { flags: INFO_DESTINATION_FLAG_LITTLE_ENDIAN, guid_prefix, }
}

///|
/// Return the INFO_DST submessage flags.
pub fn InfoDestinationSubmessage::flags(
  self : InfoDestinationSubmessage,
) -> Byte {
  self.flags
}

///|
/// Return the destination GUID prefix.
pub fn InfoDestinationSubmessage::guid_prefix(
  self : InfoDestinationSubmessage,
) -> GuidPrefix {
  self.guid_prefix
}

///|
/// Serialize the INFO_DST body without its four-byte submessage header.
pub fn InfoDestinationSubmessage::to_payload(
  self : InfoDestinationSubmessage,
) -> Bytes {
  self.guid_prefix.as_bytes()
}

///|
/// Wrap this destination in an RTPS INFO_DST submessage.
pub fn InfoDestinationSubmessage::to_submessage(
  self : InfoDestinationSubmessage,
) -> Submessage {
  Submessage::new(InfoDestination, self.flags, self.to_payload())
}

///|
/// Build an RTPS message containing this INFO_DST submessage.
pub fn InfoDestinationSubmessage::to_message(
  self : InfoDestinationSubmessage,
  guid_prefix : GuidPrefix,
  vendor_id : VendorId,
) -> Message {
  let message = Message::new(Header::new(guid_prefix, vendor_id))
  message.add(self.to_submessage())
  message
}

///|
/// Parse an RTPS INFO_DST submessage.
pub fn InfoDestinationSubmessage::from_submessage(
  submessage : Submessage,
) -> Result[InfoDestinationSubmessage, String] {
  if submessage.id() != InfoDestination {
    return Err("expected an RTPS INFO_DST submessage")
  }
  if submessage.payload.length() != 12 {
    return Err("an RTPS INFO_DST body must be 12 bytes")
  }
  let guid_prefix = match GuidPrefix::new(submessage.payload) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ flags: submessage.flags(), guid_prefix, })
}
