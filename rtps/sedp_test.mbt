///|
fn sedp_test_guid(kind : Byte) -> Result[Guid, String] {
  match GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Err(message) => Err(message)
    Ok(prefix) =>
      match EntityId::new(b"abc", kind) {
        Err(message) => Err(message)
        Ok(entity_id) => Ok(Guid::new(prefix, entity_id))
      }
  }
}

///|
test "SEDP endpoint data round trips required fields and locators" {
  let endpoint_guid = match sedp_test_guid(0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let participant_guid = match sedp_test_guid(0xC1) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let locator = match Locator::udp_v4(b"\x7F\x00\x00\x01", 7410) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let endpoint = match
    SedpEndpointData::new(
      SedpEndpointKind::Publication,
      endpoint_guid,
      "rt/chatter",
      "std_msgs::msg::dds_::String_",
    ) {
    Ok(value) => value.with_participant_guid(participant_guid)
    Err(message) => fail(message)
  }
  endpoint.add_unicast_locator(locator)
  endpoint.add_parameter(
    Parameter::new(
      PID_RELIABILITY,
      b"\x02\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
    ),
  )
  let encoded = match endpoint.to_cdr_bytes() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let decoded = match
    SedpEndpointData::from_cdr_bytes(SedpEndpointKind::Publication, encoded) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.endpoint_guid(), endpoint_guid)
  assert_eq(decoded.participant_guid(), participant_guid)
  assert_eq(decoded.topic_name(), "rt/chatter")
  assert_eq(decoded.type_name(), "std_msgs::msg::dds_::String_")
  assert_eq(decoded.kind(), SedpEndpointKind::Publication)
  let reencoded = match decoded.to_cdr_bytes() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(reencoded, encoded)
  let reader_id = match EntityId::new(b"rdr", 0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match EntityId::new(b"wrt", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let data = match endpoint.to_data_submessage(reader_id, writer_id, 1L) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let parsed = match
    SedpEndpointData::from_data_submessage(SedpEndpointKind::Publication, data) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(parsed.topic_name(), endpoint.topic_name())
  let message = match
    endpoint.to_message(VendorId::new(1, 15), reader_id, writer_id, 1L) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(message.submessages().length(), 1)
}

///|
test "SEDP parser rejects missing required fields" {
  let parameters = ParameterList::new()
  parameters.add(Parameter::new(PID_TOPIC_NAME, b"\x01\x00\x00\x00\x00"))
  assert_true(
    SedpEndpointData::from_parameter_list(
      SedpEndpointKind::Subscription,
      parameters,
    )
    is Err(_),
  )
}

///|
test "SEDP resolves predefined builtin writer entity IDs" {
  let publication_writer = match EntityId::new(b"\x00\x00\x03", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let subscription_writer = match EntityId::new(b"\x00\x00\x04", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let unknown_writer = match EntityId::new(b"\x00\x00\x05", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(
    SedpEndpointKind::from_builtin_writer_id(publication_writer),
    Ok(SedpEndpointKind::Publication),
  )
  assert_eq(
    SedpEndpointKind::from_builtin_writer_id(subscription_writer),
    Ok(SedpEndpointKind::Subscription),
  )
  assert_true(
    SedpEndpointKind::from_builtin_writer_id(unknown_writer) is Err(_),
  )
}

///|
test "SEDP resolves builtin reader and writer IDs by endpoint kind" {
  let publication_reader = SedpEndpointKind::Publication.builtin_reader_id()
  let publication_writer = SedpEndpointKind::Publication.builtin_writer_id()
  let subscription_reader = SedpEndpointKind::Subscription.builtin_reader_id()
  let subscription_writer = SedpEndpointKind::Subscription.builtin_writer_id()
  assert_eq(publication_reader.key(), b"\x00\x00\x03")
  assert_eq(publication_reader.kind(), 0xC7)
  assert_eq(publication_writer.key(), b"\x00\x00\x03")
  assert_eq(publication_writer.kind(), 0xC2)
  assert_eq(subscription_reader.key(), b"\x00\x00\x04")
  assert_eq(subscription_reader.kind(), 0xC7)
  assert_eq(subscription_writer.key(), b"\x00\x00\x04")
  assert_eq(subscription_writer.kind(), 0xC2)
}
