///|
/// The ROS 2 `std_msgs/msg/String` message.
pub const STD_MSGS_STRING_TYPE_HASH : String = "RIHS01_df668c740482bbd48fb39d76a70dfd4bd59db1288021743503259e948f6b1a18"

///|
pub struct StringMessage {
  data : String
}

///|
pub fn StringMessage::new(data : String) -> StringMessage {
  { data, }
}

///|
pub fn StringMessage::data(self : StringMessage) -> String {
  self.data
}

///|
/// Serialize `std_msgs/msg/String` using CDR little-endian encoding.
pub fn StringMessage::to_cdr_bytes(self : StringMessage) -> Bytes {
  let writer = @cdr.Writer::new()
  writer.write_string(self.data)
  writer.to_bytes()
}

///|
/// Parse a CDR little-endian `std_msgs/msg/String` message.
pub fn StringMessage::from_cdr_bytes(
  input : Bytes,
) -> Result[StringMessage, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let data = match reader.read_string() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if !reader.remaining_is_zero_padding(4) {
    return Err("trailing bytes after std_msgs/msg/String")
  }
  Ok(StringMessage::new(data))
}
