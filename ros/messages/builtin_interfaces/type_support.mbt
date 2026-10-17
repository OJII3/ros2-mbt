///|
/// Return the `builtin_interfaces/msg/Time` wire identity and codecs.
pub fn Time::type_support() -> @endpoints.RosMessageType[Time] {
  @endpoints.RosMessageType::new(
    "builtin_interfaces",
    "msg",
    "Time",
    Time_TYPE_HASH,
    fn(message) { Time::to_cdr_bytes(message) },
    Time::from_cdr_bytes,
  )
}

///|
/// Return the `builtin_interfaces/msg/Duration` wire identity and codecs.
pub fn Duration::type_support() -> @endpoints.RosMessageType[Duration] {
  @endpoints.RosMessageType::new(
    "builtin_interfaces",
    "msg",
    "Duration",
    Duration_TYPE_HASH,
    fn(message) { Duration::to_cdr_bytes(message) },
    Duration::from_cdr_bytes,
  )
}
