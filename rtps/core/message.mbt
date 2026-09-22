///|
/// An RTPS message containing one fixed header and zero or more submessages.
pub struct Message {
  header : Header
  submessages : Array[Submessage]
} derive(Eq, Debug)

///|
pub fn Message::new(header : Header) -> Message {
  { header, submessages: [], }
}

///|
pub fn Message::add(self : Message, submessage : Submessage) -> Unit {
  self.submessages.push(submessage)
}

///|
pub fn Message::header(self : Message) -> Header {
  self.header
}

///|
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
/// Return the optional INFO_DST participant prefix carried by this message.
pub fn Message::destination_guid_prefix(
  self : Message,
) -> Result[GuidPrefix?, String] {
  let mut destination : GuidPrefix? = None
  for submessage in self.submessages {
    if submessage.id() != InfoDestination {
      continue
    }
    let info = match InfoDestinationSubmessage::from_submessage(submessage) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    destination = Some(info.guid_prefix())
  }
  Ok(destination)
}

///|
/// Serialize the RTPS header followed by all submessages.
pub fn Message::to_bytes(self : Message) -> Result[Bytes, String] {
  let bytes : Array[Byte] = []
  let header = self.header.to_bytes()
  for i in 0..<header.length() {
    bytes.push(header[i])
  }
  for index in 0..<self.submessages.length() {
    let submessage = self.submessages[index]
    let encoded = match submessage.to_bytes() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    for i in 0..<encoded.length() {
      bytes.push(encoded[i])
    }
    if index + 1 < self.submessages.length() {
      let remainder = encoded.length() % 4
      if remainder != 0 {
        let padding_length = 4 - remainder
        let padding : Array[Byte] = []
        for _ in 0..<padding_length {
          padding.push(0)
        }
        let encoded_padding = match
          Submessage::new(
            Pad,
            SUBMESSAGE_FLAG_LITTLE_ENDIAN,
            Bytes::from_array(padding),
          ).to_bytes() {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        for i in 0..<encoded_padding.length() {
          bytes.push(encoded_padding[i])
        }
      }
    }
  }
  Ok(Bytes::from_array(bytes))
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
    let parsed = match
      Submessage::from_bytes(bytes_from(input, offset, input.length() - offset)) {
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
