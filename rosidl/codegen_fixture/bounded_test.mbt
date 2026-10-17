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
  let endpoint = topic
    .to_sedp_with_qos_and_type_hash(
      @rtps.SedpEndpointKind::Publication,
      @rtps.Guid::new(
        @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]).unwrap(),
        @rtps.EntityId::new(b"pub", 0x03).unwrap(),
      ),
      @rtps.SedpQos::new(
        @rtps.RELIABILITY_BEST_EFFORT,
        @rtps.DURABILITY_VOLATILE,
        @rtps.HISTORY_KEEP_LAST,
        10,
      ),
      support.type_hash(),
    )
    .unwrap()
  assert_eq(endpoint.type_hash(), Ok(Some(support.type_hash())))
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
