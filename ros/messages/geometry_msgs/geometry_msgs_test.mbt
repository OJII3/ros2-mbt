///|
test "geometry_msgs Twist CDR round trip" {
  let message = @geometry_msgs.Twist::new(
    @geometry_msgs.Vector3::new(1.5, -2.0, 3.25),
    @geometry_msgs.Vector3::new(-4.5, 5.0, 6.75),
  )
  let encoded = message.to_cdr_bytes()
  assert_eq(encoded.length(), 52)
  let decoded = match @geometry_msgs.Twist::from_cdr_bytes(encoded) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded, message)
}
