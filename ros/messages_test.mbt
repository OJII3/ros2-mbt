///|
test "std_msgs String CDR round trip" {
  assert_eq(
    STD_MSGS_STRING_TYPE_HASH,
    "RIHS01_df668c740482bbd48fb39d76a70dfd4bd59db1288021743503259e948f6b1a18",
  )
  let message = StringMessage::new("hello ROS 2")
  let encoded = message.to_cdr_bytes()
  assert_eq(encoded[0], 0)
  assert_eq(encoded[1], 1)
  let decoded = match StringMessage::from_cdr_bytes(encoded) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.data(), "hello ROS 2")
}

///|
test "geometry_msgs Twist CDR round trip" {
  let message = Twist::new(
    Vector3::new(1.5, -2.0, 3.25),
    Vector3::new(-4.5, 5.0, 6.75),
  )
  let encoded = message.to_cdr_bytes()
  assert_eq(encoded.length(), 56)
  let decoded = match Twist::from_cdr_bytes(encoded) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded, message)
}

///|
test "ROS message parsers reject trailing data" {
  let encoded = StringMessage::new("x").to_cdr_bytes()
  let bytes : Array[Byte] = []
  for i in 0..<encoded.length() {
    bytes.push(encoded[i])
  }
  bytes.push(1)
  let with_trailing = Bytes::from_array(bytes)
  assert_true(StringMessage::from_cdr_bytes(with_trailing) is Err(_))
}
