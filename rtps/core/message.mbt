///|
/// An RTPS message containing one fixed header and zero or more submessages.
#derive(Eq, Debug)
pub struct Message {
  header : Header
  submessages : Array[Submessage]
}

///|
pub extend Message with Eq::{not_equal, equal}

///|
pub extend Message with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Create an RTPS message with the given header.
pub fn Message::new(header : Header) -> Message {
  { header, submessages: [], }
}

///|
/// Append a submessage to the RTPS message.
pub fn Message::add(self : Message, submessage : Submessage) -> Unit {
  self.submessages.push(submessage)
}

///|
/// Return the RTPS message header.
pub fn Message::header(self : Message) -> Header {
  self.header
}

///|
/// Return the RTPS message submessages.
pub fn Message::submessages(self : Message) -> Array[Submessage] {
  self.submessages
}

///|
/// Return a copy with an INFO_DST submessage before the existing submessages.
pub fn Message::with_destination_guid_prefix(
  self : Message,
  guid_prefix : GuidPrefix,
) -> Message {
  let message = Message::new(self.header)
  message.add(InfoDestinationSubmessage::new(guid_prefix).to_submessage())
  for submessage in self.submessages {
    message.add(submessage)
  }
  message
}

///|
/// Return the INFO_DST context that applies at each submessage position.
///
/// The returned array has one entry per submessage. An entry is `None` when
/// no INFO_DST has appeared yet, and otherwise contains the most recent
/// destination prefix.
pub fn Message::destination_contexts(
  self : Message,
) -> Result[Array[GuidPrefix?], String] {
  let destinations : Array[GuidPrefix?] = []
  let mut destination : GuidPrefix? = None
  for submessage in self.submessages {
    if submessage.id() == InfoDestination {
      let info = match InfoDestinationSubmessage::from_submessage(submessage) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      destination = Some(info.guid_prefix())
    }
    destinations.push(destination)
  }
  Ok(destinations)
}

///|
/// Serialize the RTPS header followed by all submessages.
pub fn Message::to_bytes(self : Message) -> Result[Bytes, String] {
  let mut capacity = HEADER_LENGTH
  for index in 0..<self.submessages.length() {
    let payload_length = self.submessages[index].payload.length()
    if payload_length > 0xFFFF {
      return Err("an RTPS submessage payload cannot exceed 65535 bytes")
    }
    capacity += SUBMESSAGE_HEADER_LENGTH + payload_length
    if index + 1 < self.submessages.length() {
      let remainder = (SUBMESSAGE_HEADER_LENGTH + payload_length) % 4
      if remainder != 0 {
        capacity += SUBMESSAGE_HEADER_LENGTH + 4 - remainder
      }
    }
  }
  let buffer = @buffer.Buffer(capacity~)
  buffer.write_bytes(self.header.to_bytes())
  for index in 0..<self.submessages.length() {
    let submessage = self.submessages[index]
    buffer.write_byte(submessage.id.to_byte())
    buffer.write_byte(submessage.flags)
    if (submessage.flags & SUBMESSAGE_FLAG_LITTLE_ENDIAN) != 0 {
      buffer.write_uint16_le(submessage.payload.length().to_uint16())
    } else {
      buffer.write_uint16_be(submessage.payload.length().to_uint16())
    }
    buffer.write_bytes(submessage.payload)
    if index + 1 < self.submessages.length() {
      let remainder = (SUBMESSAGE_HEADER_LENGTH + submessage.payload.length()) %
        4
      if remainder != 0 {
        buffer.write_byte(Pad.to_byte())
        buffer.write_byte(SUBMESSAGE_FLAG_LITTLE_ENDIAN)
        buffer.write_uint16_le((4 - remainder).to_uint16())
        for _ in 0..<(4 - remainder) {
          buffer.write_byte(0)
        }
      }
    }
  }
  Ok(buffer.to_bytes())
}

///|
/// Parse an RTPS message and all of its submessages.
pub fn Message::from_bytes(input : Bytes) -> Result[Message, String] {
  let header = match Header::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let message = Message::new(header)
  let mut offset = HEADER_LENGTH
  while offset < input.length() {
    let parsed = match Submessage::from_bytes_at(input, offset) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let (submessage, consumed) = parsed
    if consumed <= 0 {
      return Err("RTPS parser consumed no bytes")
    }
    message.add(submessage)
    offset += consumed
  }
  Ok(message)
}
