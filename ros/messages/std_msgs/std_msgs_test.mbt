///|
test "std_msgs String CDR round trip" {
  assert_eq(
    @std_msgs.STD_MSGS_STRING_TYPE_HASH,
    "RIHS01_df668c740482bbd48fb39d76a70dfd4bd59db1288021743503259e948f6b1a18",
  )
  let message = @std_msgs.StringMessage::new("hello ROS 2")
  let encoded = message.to_cdr_bytes()
  assert_eq(encoded[0], 0)
  assert_eq(encoded[1], 1)
  let decoded = match @std_msgs.StringMessage::from_cdr_bytes(encoded) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.data(), "hello ROS 2")
}

///|
test "std_msgs Header CDR round trip preserves timestamp and frame id" {
  let header = @std_msgs.Header::new(
    @builtin_interfaces.Time::new(123, 456789012U),
    "map",
  )
  let decoded = match
    @std_msgs.Header::from_cdr_bytes(header.to_cdr_bytes().unwrap()) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded, header)
}

///|
test "ROS message parsers reject trailing data" {
  let encoded = @std_msgs.StringMessage::new("x").to_cdr_bytes()
  let bytes : Array[Byte] = []
  for i in 0..<encoded.length() {
    bytes.push(encoded[i])
  }
  bytes.push(1)
  let with_trailing = Bytes::from_array(bytes)
  assert_true(@std_msgs.StringMessage::from_cdr_bytes(with_trailing) is Err(_))
}
