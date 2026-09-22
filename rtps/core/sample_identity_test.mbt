///|
test "RTPS sample identity round trip" {
  let prefix = match
    @core.GuidPrefix::from_array([11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let entity_id = match @core.EntityId::new(b"abc", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let identity = match
    @core.SampleIdentity::new(@core.Guid::new(prefix, entity_id), 42L) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(identity.to_bytes().length(), 24)
  assert_eq(identity.to_bytes()[16:24], b"\x00\x00\x00\x00\x2A\x00\x00\x00")
  assert_eq(@core.SampleIdentity::from_bytes(identity.to_bytes()), Ok(identity))
  let unknown = @core.SampleIdentity::unknown_sequence(identity.writer_guid())
  assert_eq(unknown.sequence_number(), @core.SAMPLE_IDENTITY_UNKNOWN_SEQUENCE)
  assert_eq(unknown.to_bytes()[16:24], b"\xFF\xFF\xFF\xFF\x00\x00\x00\x00")
  assert_eq(@core.SampleIdentity::from_bytes(unknown.to_bytes()), Ok(unknown))
  assert_true(@core.SampleIdentity::new(identity.writer_guid(), 0L) is Err(_))
}
