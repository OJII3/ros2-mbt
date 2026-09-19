///|
test "RTPS parameter list round trip" {
  let parameters = ParameterList::new()
  parameters.add(Parameter::new(PID_PROTOCOL_VERSION, b"\x02\x03\x00\x00"))
  parameters.add(Parameter::new(PID_VENDOR_ID, b"\x01\x0F\x00\x00"))
  let encoded = parameters.to_cdr_bytes()
  assert_eq(
    encoded, b"\x00\x01\x00\x00\x15\x00\x04\x00\x02\x03\x00\x00\x16\x00\x04\x00\x01\x0F\x00\x00\x01\x00\x00\x00",
  )
  let decoded = match ParameterList::from_cdr_bytes(encoded) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.values(), parameters.values())
}

///|
test "RTPS parameter list pads values to four bytes" {
  let parameters = ParameterList::new()
  parameters.add(Parameter::new(0x8000, b"abc"))
  assert_eq(parameters.to_bytes(), b"\x00\x80\x03\x00abc\x00\x01\x00\x00\x00")
}

///|
test "RTPS parameter list rejects malformed input" {
  assert_true(ParameterList::from_bytes(b"\x15\x00\x04") is Err(_))
  assert_true(ParameterList::from_bytes(b"\x15\x00\x00\x00") is Err(_))
  assert_true(ParameterList::from_cdr_bytes(b"\x00\x00\x00\x00") is Err(_))
}

///|
test "RTPS discovery locator parameter identifiers match the wire standard" {
  assert_eq(PID_DEFAULT_UNICAST_LOCATOR, 0x0031)
  assert_eq(PID_METATRAFFIC_UNICAST_LOCATOR, 0x0032)
  assert_eq(PID_METATRAFFIC_MULTICAST_LOCATOR, 0x0033)
  assert_eq(PID_DEFAULT_MULTICAST_LOCATOR, 0x0048)
}
