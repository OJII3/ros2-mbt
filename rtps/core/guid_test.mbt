///|
test "RTPS GUID round trip" {
  let prefix = match
    @core.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let entity_id = match @core.EntityId::new(b"abc", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let guid = @core.Guid::new(prefix, entity_id)
  assert_eq(
    guid.to_bytes(),
    b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0Babc\xC2",
  )
  let decoded = match @core.Guid::from_bytes(guid.to_bytes()) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded, guid)
  assert_eq(decoded.entity_id().kind(), 0xC2)
}

///|
test "RTPS unknown entity ID is the zero entity ID" {
  assert_eq(@core.EntityId::unknown().to_bytes(), b"\x00\x00\x00\x00")
}

///|
test "RTPS GUID rejects invalid lengths" {
  assert_true(@core.EntityId::new(b"ab", 0) is Err(_))
  assert_true(@core.EntityId::from_bytes(b"abc") is Err(_))
  assert_true(@core.Guid::from_bytes(b"short") is Err(_))
}
