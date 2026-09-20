///|
test "generated integer constant literals compile at signed and unsigned limits" {
  assert_eq(MIN, -128)
  assert_eq(BYTE, 255)
  assert_eq(OCTAL, 32767)
  assert_eq(BINARY, 4294967295U)
  assert_eq(WIDE, -9223372036854775808L)
  assert_eq(UNSIGNED, 18446744073709551615UL)
}
