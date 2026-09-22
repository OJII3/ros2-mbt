///|
test "generated exponent float constant literals compile" {
  assert_eq(@codegen_fixture.SMALL, 1.25e-3F)
  assert_eq(@codegen_fixture.WHOLE, 1.0F)
  assert_eq(@codegen_fixture.LARGE, -2.0e+9)
  assert_eq(@codegen_fixture.LEADING, 0.5)
  assert_eq(@codegen_fixture.TRAILING, 1.0)
  assert_eq(@codegen_fixture.GROUPED, 1000.5e+2)
}
