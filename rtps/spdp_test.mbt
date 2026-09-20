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
test "SPDP decodes PL_CDR_BE participant fields and locators" {
  let guid = spdp_test_guid().unwrap()
  let locator = Locator::udp_v4(b"\x7F\x00\x00\x01", 7400U).unwrap()
  let payload : Array[Byte] = [0, 2, 0, 0]
  parameter_test_append_be_parameter(
    payload,
    PID_PROTOCOL_VERSION,
    b"\x02\x03\x00\x00",
  )
  parameter_test_append_be_parameter(
    payload,
    PID_VENDOR_ID,
    b"\x01\x0F\x00\x00",
  )
  parameter_test_append_be_parameter(
    payload,
    PID_PARTICIPANT_GUID,
    guid.to_bytes(),
  )
  let lease : Array[Byte] = []
  parameter_test_append_u32_be(lease, 60U)
  parameter_test_append_u32_be(lease, 0U)
  parameter_test_append_be_parameter(
    payload,
    PID_PARTICIPANT_LEASE_DURATION,
    Bytes::from_array(lease),
  )
  parameter_test_append_be_parameter(
    payload,
    PID_DOMAIN_ID,
    parameter_test_be_u32(42U),
  )
  let locator_value : Array[Byte] = []
  parameter_test_append_u32_be(
    locator_value,
    locator.kind().reinterpret_as_uint(),
  )
  parameter_test_append_u32_be(locator_value, locator.port())
  for byte in locator.address() {
    locator_value.push(byte)
  }
  parameter_test_append_be_parameter(
    payload,
    PID_METATRAFFIC_UNICAST_LOCATOR,
    Bytes::from_array(locator_value),
  )
  parameter_test_append_be_parameter(
    payload,
    PID_BUILTIN_ENDPOINT_SET,
    parameter_test_be_u32(3U),
  )
  parameter_test_append_be_parameter(payload, PID_SENTINEL, b"")

  let serialized_payload = Bytes::from_array(payload)
  let decoded = SpdpParticipantData::from_cdr_bytes(serialized_payload).unwrap()
  assert_eq(decoded.participant_guid(), guid)
  assert_eq(decoded.vendor_id(), VendorId::new(1, 15))
  assert_eq(decoded.domain_id(), 42U)
  assert_eq(decoded.lease_seconds(), 60)
  assert_eq(decoded.lease_nanoseconds(), 0U)
  assert_eq(decoded.metatraffic_unicast_locators(), [locator])
  let data = DataSubmessage::new(
    EntityId::new(b"rdr", ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER).unwrap(),
    EntityId::new(b"wrt", ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER).unwrap(),
    1L,
    serialized_payload,
  )
  assert_eq(
    SpdpParticipantData::from_data_submessage(data).unwrap().domain_id(),
    42U,
  )
}

///|
test "SPDP participant lease duration uses RTPS fractional seconds" {
  let participant = SpdpParticipantData::new(
    spdp_test_guid().unwrap(),
    VendorId::new(1, 15),
    0,
    2,
    500_000_000U,
    BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER,
  )
  let lease = participant.to_parameter_list().values()[3]
  assert_eq(lease.value(), b"\x02\x00\x00\x00\x00\x00\x00\x80")
  let decoded = SpdpParticipantData::from_parameter_list(
    participant.to_parameter_list(),
  ).unwrap()
  assert_eq(decoded.lease_seconds(), 2)
  assert_eq(decoded.lease_nanoseconds(), 500_000_000U)
}

///|
test "SPDP parser requires a participant GUID" {
  let parameters = ParameterList::new()
  parameters.add(Parameter::new(PID_DOMAIN_ID, b"\x00\x00\x00\x00"))
  assert_true(SpdpParticipantData::from_parameter_list(parameters) is Err(_))
}

///|
test "SPDP parser rejects invalid participant lease durations" {
  let parameters = ParameterList::new()
  parameters.add(Parameter::new(PID_PARTICIPANT_GUID, spdp_test_guid().unwrap().to_bytes()))
  parameters.add(
    Parameter::new(
      PID_PARTICIPANT_LEASE_DURATION,
      Bytes::from_array([0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0]),
    ),
  )
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

///|
test "SPDP DATA accepts an unencapsulated ParameterList" {
  let guid = spdp_test_guid().unwrap()
  let participant = SpdpParticipantData::new(
    guid,
    VendorId::new(1, 15),
    0,
    60,
    0,
    BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER |
    BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR,
  )
  let reader_id = EntityId::new(b"rdr", ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER).unwrap()
  let writer_id = EntityId::new(b"wrt", ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER).unwrap()
  let cdr = participant.to_cdr_bytes()
  let data = DataSubmessage::new(reader_id, writer_id, 1L, cdr[4:].to_owned())
  let decoded = SpdpParticipantData::from_data_submessage(data).unwrap()
  assert_eq(decoded.to_cdr_bytes(), cdr)
}

///|
test "SPDP extracts a participant GUID from key-only data" {
  let guid = spdp_test_guid().unwrap()
  let reader_id = EntityId::new(b"rdr", ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER).unwrap()
  let writer_id = EntityId::new(b"wrt", ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER).unwrap()
  let data = DataSubmessage::new(reader_id, writer_id, 2L, b"")
    .with_key(guid.to_bytes())
  assert_eq(
    SpdpParticipantData::participant_guid_from_key_data(data).unwrap(),
    guid,
  )
}

///|
test "SPDP builds a participant dispose DATA sample" {
  let guid = spdp_test_guid().unwrap()
  let participant = SpdpParticipantData::new(
    guid,
    VendorId::new(1, 15),
    0,
    60,
    0,
    BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER,
  )
  let reader_id = EntityId::new(b"rdr", ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER).unwrap()
  let writer_id = EntityId::new(b"wrt", ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER).unwrap()
  let data = participant.to_dispose_data_submessage(reader_id, writer_id, 3L)
  assert_true((data.flags() & DATA_FLAG_KEY) != 0x00)
  assert_eq(
    data.status_info(),
    Ok(Some(STATUS_INFO_DISPOSED | STATUS_INFO_UNREGISTERED)),
  )
  assert_eq(
    SpdpParticipantData::participant_guid_from_key_data(data).unwrap(),
    guid,
  )
}
