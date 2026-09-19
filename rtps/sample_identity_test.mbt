///|
test "RTPS sample identity round trip" {
  let prefix = match
    GuidPrefix::from_array([11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let entity_id = match EntityId::new(b"abc", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let identity = match SampleIdentity::new(Guid::new(prefix, entity_id), 42L) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(identity.to_bytes().length(), 24)
  assert_eq(SampleIdentity::from_bytes(identity.to_bytes()), Ok(identity))
  let unknown = SampleIdentity::unknown_sequence(identity.writer_guid())
  assert_eq(SampleIdentity::from_bytes(unknown.to_bytes()), Ok(unknown))
  assert_true(SampleIdentity::new(identity.writer_guid(), 0L) is Err(_))
}
