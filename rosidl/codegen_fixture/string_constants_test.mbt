///|
test "generated string constant literals preserve their values" {
  assert_eq(@codegen_fixture.SINGLE, "single quoted")
  assert_eq(@codegen_fixture.RAW, "unquoted value")
  assert_eq(@codegen_fixture.ESCAPED, "say \"hi\"")
  assert_eq(@codegen_fixture.UNICODE, "猫")
}
