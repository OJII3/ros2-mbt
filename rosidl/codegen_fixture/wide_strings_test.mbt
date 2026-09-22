///|
test "generated wide-string codec round trips Unicode and defaults" {
  let message = @codegen_fixture.WideStrings::default()
  let encoded = message.to_cdr_bytes().unwrap()
  assert_eq(@codegen_fixture.WideStrings::from_cdr_bytes(encoded), Ok(message))

  let invalid = @codegen_fixture.WideStrings::new("text", "猫🙂", [])
  assert_true(invalid.to_cdr_bytes() is Err(_))
}
