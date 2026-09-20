///|
test "generated exponent float constant literals compile" {
  assert_eq(SMALL, 1.25e-3F)
  assert_eq(WHOLE, 1.0F)
  assert_eq(LARGE, -2.0e+9)
  assert_eq(LEADING, 0.5)
  assert_eq(TRAILING, 1.0)
  assert_eq(GROUPED, 1000.5e+2)
}
