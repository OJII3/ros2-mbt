///|
fn spdp_test_guid() -> Result[Guid, String] {
  match GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Err(message) => Err(message)
    Ok(prefix) =>
      match EntityId::new(b"abc", 0xC1) {
        Err(message) => Err(message)
        Ok(entity_id) => Ok(Guid::new(prefix, entity_id))
      }
  }
}

///|
test "SPDP participant data builds RTPS parameters" {
  let guid = match spdp_test_guid() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let locator = match Locator::udp_v4(b"\x7F\x00\x00\x01", 7400) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let participant = SpdpParticipantData::new(
    guid,
    VendorId::new(1, 15),
    42,
    60,
    0,
    BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER |
    BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR,
  )
  participant.add_metatraffic_unicast(locator)
  participant.add_default_unicast(locator)
  let parameters = participant.to_parameter_list()
  let values = parameters.values()
  assert_eq(values[0].id(), PID_PROTOCOL_VERSION)
  assert_eq(values[1].id(), PID_VENDOR_ID)
  assert_eq(values[2].id(), PID_PARTICIPANT_GUID)
  assert_eq(values[3].id(), PID_PARTICIPANT_LEASE_DURATION)
  assert_eq(values[4].id(), PID_DOMAIN_ID)
  assert_eq(values[5].id(), PID_METATRAFFIC_UNICAST_LOCATOR)
  assert_eq(values[6].id(), PID_DEFAULT_UNICAST_LOCATOR)
  assert_eq(values[7].id(), PID_BUILTIN_ENDPOINT_SET)
  assert_eq(values[5].value(), locator.to_bytes())
  assert_eq(values[7].value(), b"\x03\x00\x00\x00")
  let decoded = match
    ParameterList::from_cdr_bytes(participant.to_cdr_bytes()) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.values(), values)
  let decoded_participant = match
    SpdpParticipantData::from_cdr_bytes(participant.to_cdr_bytes()) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded_participant.to_cdr_bytes(), participant.to_cdr_bytes())
}

///|
test "SPDP parser requires a participant GUID" {
  let parameters = ParameterList::new()
  parameters.add(Parameter::new(PID_DOMAIN_ID, b"\x00\x00\x00\x00"))
  assert_true(SpdpParticipantData::from_parameter_list(parameters) is Err(_))
}

///|
test "SPDP participant data creates a DATA submessage" {
  let guid = match spdp_test_guid() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let participant = SpdpParticipantData::new(
    guid,
    VendorId::new(1, 15),
    0,
    100,
    0,
    BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER |
    BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR,
  )
  let reader_id = match
    EntityId::new(b"rdr", ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match
    EntityId::new(b"wrt", ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let data = participant.to_data_submessage(reader_id, writer_id, 1L)
  assert_eq(data.serialized_payload(), participant.to_cdr_bytes())
  assert_eq(data.writer_sequence_number(), 1L)
  let parsed_participant = match
    SpdpParticipantData::from_data_submessage(data) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(parsed_participant.to_cdr_bytes(), participant.to_cdr_bytes())
  let message = participant.to_message(reader_id, writer_id, 1L)
  assert_eq(message.submessages().length(), 1)
  assert_eq(message.header().to_bytes()[0], b'R')
}
