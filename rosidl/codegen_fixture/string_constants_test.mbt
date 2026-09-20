///|
test "generated string constant literals preserve their values" {
  assert_eq(SINGLE, "single quoted")
  assert_eq(RAW, "unquoted value")
  assert_eq(ESCAPED, "say \"hi\"")
  assert_eq(UNICODE, "猫")
}
