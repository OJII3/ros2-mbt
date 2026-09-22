///|
fn parameter_test_append_u16_be(bytes : Array[Byte], value : UInt) -> Unit {
  bytes.push((value >> 8).to_byte())
  bytes.push(value.to_byte())
}

///|
fn parameter_test_append_be_parameter(
  bytes : Array[Byte],
  id : UInt16,
  value : Bytes,
) -> Unit {
  let length = (value.length() + 3) / 4 * 4
  parameter_test_append_u16_be(bytes, id.to_int().reinterpret_as_uint())
  parameter_test_append_u16_be(bytes, length.reinterpret_as_uint())
  for byte in value {
    bytes.push(byte)
  }
  for _ in 0..<(length - value.length()) {
    bytes.push(0)
  }
}

///|
test "RTPS parameter list round trip" {
  let parameters = @core.ParameterList::new()
  parameters.add(
    @core.Parameter::new(@core.PID_PROTOCOL_VERSION, b"\x02\x03\x00\x00"),
  )
  parameters.add(@core.Parameter::new(@core.PID_VENDOR_ID, b"\x01\x0F\x00\x00"))
  let encoded = parameters.to_cdr_bytes()
  assert_eq(
    encoded, b"\x00\x03\x00\x00\x15\x00\x04\x00\x02\x03\x00\x00\x16\x00\x04\x00\x01\x0F\x00\x00\x01\x00\x00\x00",
  )
  let decoded = match @core.ParameterList::from_cdr_bytes(encoded) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.values(), parameters.values())
}

///|
test "RTPS PL_CDR_BE decodes parameter headers and normalizes known fields" {
  let encoded : Array[Byte] = [0, 2, 0x12, 0x34]
  parameter_test_append_be_parameter(
    encoded,
    @core.PID_DOMAIN_ID,
    b"\x00\x00\x00\x2A",
  )
  parameter_test_append_be_parameter(encoded, 0x8000, b"\x10\x20\x30\x40")
  parameter_test_append_be_parameter(encoded, @core.PID_SENTINEL, b"")
  let payload = Bytes::from_array(encoded)
  let decoded = @core.ParameterList::from_cdr_bytes(payload).unwrap()
  assert_eq(decoded.values()[0].id(), @core.PID_DOMAIN_ID)
  assert_eq(decoded.values()[0].value(), b"\x2A\x00\x00\x00")
  assert_eq(decoded.values()[1].id(), (0x8000 : UInt16))
  assert_eq(decoded.values()[1].value(), b"\x10\x20\x30\x40")
  assert_eq(
    @core.ParameterList::from_data_bytes(payload).unwrap().values(),
    decoded.values(),
  )
}

///|
test "RTPS DATA parameter list accepts a payload without encapsulation" {
  let parameters = @core.ParameterList::new()
  parameters.add(
    @core.Parameter::new(@core.PID_PROTOCOL_VERSION, b"\x02\x03\x00\x00"),
  )
  parameters.add(@core.Parameter::new(@core.PID_VENDOR_ID, b"\x01\x0F\x00\x00"))
  let encoded = parameters.to_cdr_bytes()
  let decoded = match
    @core.ParameterList::from_data_bytes(encoded[4:].to_owned()) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.values(), parameters.values())
}

///|
test "RTPS parameter list pads values to four bytes" {
  let parameters = @core.ParameterList::new()
  parameters.add(@core.Parameter::new(0x8000, b"abc"))
  assert_eq(parameters.to_bytes(), b"\x00\x80\x04\x00abc\x00\x01\x00\x00\x00")
}

///|
test "RTPS parameter list rejects malformed input" {
  assert_true(@core.ParameterList::from_bytes(b"\x15\x00\x04") is Err(_))
  assert_true(@core.ParameterList::from_bytes(b"\x15\x00\x00\x00") is Err(_))
  assert_true(
    @core.ParameterList::from_cdr_bytes(b"\x00\x00\x00\x00") is Err(_),
  )
}

///|
test "RTPS discovery locator parameter identifiers match the wire standard" {
  assert_eq(@core.PID_DEFAULT_UNICAST_LOCATOR, 0x0031)
  assert_eq(@core.PID_METATRAFFIC_UNICAST_LOCATOR, 0x0032)
  assert_eq(@core.PID_METATRAFFIC_MULTICAST_LOCATOR, 0x0033)
  assert_eq(@core.PID_DEFAULT_MULTICAST_LOCATOR, 0x0048)
}

///|
test "DDS-RPC service discovery parameter identifiers match the wire standard" {
  assert_eq(@core.PID_SERVICE_INSTANCE_NAME, 0x0080)
  assert_eq(@core.PID_RELATED_ENTITY_GUID, 0x0081)
  assert_eq(@core.PID_TOPIC_ALIASES, 0x0082)
  assert_eq(@core.PID_RELATED_SAMPLE_IDENTITY, 0x0083)
}
