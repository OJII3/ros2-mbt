///|
test "generated field default constructor applies scalar and array defaults" {
  assert_eq(
    @codegen_fixture.Defaulted::default(),
    @codegen_fixture.Defaulted::new(true, 42, "hello world", [1, 2, 3], [], [
      0, 0,
    ]),
  )
}
