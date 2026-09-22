///|
test "RTPS IPv4 locator round trip" {
  let locator = match @core.Locator::udp_v4(b"\x7F\x00\x00\x01", 7400) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(locator.kind(), @core.LOCATOR_KIND_UDP_V4)
  assert_eq(locator.port(), 7400)
  assert_eq(
    locator.to_bytes(),
    b"\x01\x00\x00\x00\xE8\x1C\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x7F\x00\x00\x01",
  )
  let decoded = match @core.Locator::from_bytes(locator.to_bytes()) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded, locator)
}

///|
test "RTPS locator preserves signed kind bits" {
  let locator = match
    @core.Locator::new(
      -1,
      0xFFFFFFFF,
      Bytes::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let decoded = match @core.Locator::from_bytes(locator.to_bytes()) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.kind(), -1)
  assert_eq(decoded.port(), 0xFFFFFFFF)
}

///|
test "RTPS locator rejects invalid lengths" {
  assert_true(@core.Locator::new(1, 7400, b"short") is Err(_))
  assert_true(@core.Locator::udp_v4(b"\x7F\x00\x00", 7400) is Err(_))
  assert_true(@core.Locator::from_bytes(b"short") is Err(_))
}
