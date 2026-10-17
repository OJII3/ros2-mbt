///|
test "generated bounded sequence codec round trips and enforces bounds" {
  let message = @codegen_fixture.Bounded::new([10, 20, 30])
  let encoded = message.to_cdr_bytes().unwrap()
  assert_eq(@codegen_fixture.Bounded::from_cdr_bytes(encoded), Ok(message))

  let writer = @cdr.Writer::new()
  assert_true(
    @codegen_fixture.Bounded::new([10, 20, 30, 40]).write_cdr(writer) is Err(_),
  )
  assert_eq(writer.length(), @cdr.ENCAPSULATION_LENGTH)

  let over_bound = @cdr.Writer::new()
  over_bound.write_u32(4U)
  over_bound.write_i32(10)
  over_bound.write_i32(20)
  over_bound.write_i32(30)
  over_bound.write_i32(40)
  assert_true(
    @codegen_fixture.Bounded::from_cdr_bytes(over_bound.to_bytes()) is Err(_),
  )
}

///|
test "generated message type support keeps identity and codecs together" {
  let message = @codegen_fixture.Bounded::new([1, 2, 3])
  let support = @codegen_fixture.Bounded::type_support()
  let encoded = support.encode(message).unwrap()
  assert_eq(support.decode(encoded).unwrap(), message)
  let topic = support.topic("/bounded").unwrap()
  assert_eq(topic.dds_type_name(), "demo::msg::dds_::Bounded_")
  assert_eq(topic.dds_name(), "rt/bounded")
  assert_eq(support.type_hash(), @codegen_fixture.Bounded_TYPE_HASH)
}

///|
test "generated bounded string codec round trips Unicode and enforces bounds" {
  let message = @codegen_fixture.BoundedString::new("猫犬鳥")
  let encoded = message.to_cdr_bytes().unwrap()
  assert_eq(
    @codegen_fixture.BoundedString::from_cdr_bytes(encoded),
    Ok(message),
  )
  assert_true(
    @codegen_fixture.BoundedString::new("猫犬鳥魚").to_cdr_bytes() is Err(_),
  )

  let writer = @cdr.Writer::new()
  writer.write_string("猫犬鳥魚")
  assert_true(
    @codegen_fixture.BoundedString::from_cdr_bytes(writer.to_bytes()) is Err(_),
  )
}
