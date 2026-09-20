///|
test "generated wide-string codec round trips Unicode and defaults" {
  let message = WideStrings::default()
  let encoded = message.to_cdr_bytes().unwrap()
  assert_eq(WideStrings::from_cdr_bytes(encoded), Ok(message))

  let invalid = WideStrings::new("text", "猫🙂", [])
  assert_true(invalid.to_cdr_bytes() is Err(_))
}
