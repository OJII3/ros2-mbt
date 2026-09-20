///|
test "generated field default constructor applies scalar and array defaults" {
  assert_eq(
    Defaulted::default(),
    Defaulted::new(true, 42, "hello world", [1, 2, 3], [], [0, 0]),
  )
}
