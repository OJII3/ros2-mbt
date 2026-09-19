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
/// Serialize the RTPS header followed by all submessages.
pub fn Message::to_bytes(self : Message) -> Result[Bytes, String] {
  let bytes : Array[Byte] = []
  let header = self.header.to_bytes()
  for i in 0..<header.length() {
    bytes.push(header[i])
  }
  for submessage in self.submessages {
    let encoded = match submessage.to_bytes() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    for i in 0..<encoded.length() {
      bytes.push(encoded[i])
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
