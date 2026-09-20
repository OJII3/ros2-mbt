///|
test "generated bounded sequence codec round trips and enforces bounds" {
  let message = Bounded::new([10, 20, 30])
  let encoded = message.to_cdr_bytes().unwrap()
  assert_eq(Bounded::from_cdr_bytes(encoded), Ok(message))

  let writer = @cdr.Writer::new()
  assert_true(Bounded::new([10, 20, 30, 40]).write_cdr(writer) is Err(_))
  assert_eq(writer.length(), @cdr.ENCAPSULATION_LENGTH)

  let over_bound = @cdr.Writer::new()
  over_bound.write_u32(4U)
  over_bound.write_i32(10)
  over_bound.write_i32(20)
  over_bound.write_i32(30)
  over_bound.write_i32(40)
  assert_true(Bounded::from_cdr_bytes(over_bound.to_bytes()) is Err(_))
}
