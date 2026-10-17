///|
/// Return the `std_msgs/msg/Header` wire identity and codecs.
pub fn Header::type_support() -> @endpoints.RosMessageType[Header] {
  @endpoints.RosMessageType::new(
    "std_msgs",
    "msg",
    "Header",
    Header_TYPE_HASH,
    fn(message) { Header::to_cdr_bytes(message) },
    Header::from_cdr_bytes,
  )
}

///|
/// Return the `std_msgs/msg/StringMessage` wire identity and codecs.
pub fn StringMessage::type_support() -> @endpoints.RosMessageType[StringMessage] {
  @endpoints.RosMessageType::new(
    "std_msgs",
    "msg",
    "String",
    STD_MSGS_STRING_TYPE_HASH,
    fn(message) { Ok(StringMessage::to_cdr_bytes(message)) },
    StringMessage::from_cdr_bytes,
  )
}
