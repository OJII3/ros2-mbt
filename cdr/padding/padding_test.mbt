///|
test "zero-filled ranges" {
  let bytes = b"\x00\x00\x01\x00"
  assert_true(@padding.is_zero_filled(bytes, 0, 2))
  assert_true(@padding.is_zero_filled(bytes, 2, 2))
  assert_true(@padding.is_zero_filled(bytes, 3, 4))
  assert_false(@padding.is_zero_filled(bytes, 0, 4))
  assert_false(@padding.is_zero_filled(bytes, 1, 3))
}
