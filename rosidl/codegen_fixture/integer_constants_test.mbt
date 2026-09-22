///|
test "generated integer constant literals compile at signed and unsigned limits" {
  assert_eq(@codegen_fixture.MIN, -128)
  assert_eq(@codegen_fixture.BYTE, 255)
  assert_eq(@codegen_fixture.OCTAL, 32767)
  assert_eq(@codegen_fixture.BINARY, 4294967295U)
  assert_eq(@codegen_fixture.WIDE, -9223372036854775808L)
  assert_eq(@codegen_fixture.UNSIGNED, 18446744073709551615UL)
}
