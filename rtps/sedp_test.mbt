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
  endpoint.add_parameter(qos_user_data(b"typehash=RIHS01_000102;\x00"))
  let encoded = match endpoint.to_cdr_bytes() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let encoded_parameters = match ParameterList::from_cdr_bytes(encoded) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let mut key_hash_found = false
  let mut type_max_size_found = false
  let mut user_data_found = false
  for parameter in encoded_parameters.values() {
    if parameter.id() == PID_KEY_HASH {
      key_hash_found = true
      assert_eq(parameter.value(), endpoint_guid.to_bytes())
    }
    if parameter.id() == PID_TYPE_MAX_SIZE_SERIALIZED {
      type_max_size_found = true
      assert_eq(parameter.value(), b"\x00\x00\x00\x00")
    }
    if parameter.id() == PID_USER_DATA {
      user_data_found = true
      assert_eq(
        parameter.value(),
        b"\x18\x00\x00\x00typehash=RIHS01_000102;\x00",
      )
    }
  }
  assert_true(key_hash_found)
  assert_true(type_max_size_found)
  assert_true(user_data_found)
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
  let decoded_user_data = decoded.extra_parameters()
  let mut decoded_user_data_found = false
  for parameter in decoded_user_data {
    if parameter.id() == PID_USER_DATA {
      decoded_user_data_found = true
      assert_eq(parameter.value(), b"typehash=RIHS01_000102;\x00")
    }
  }
  assert_true(decoded_user_data_found)
  assert_eq(
    decoded.type_hash(),
    Ok(Some("RIHS01_000102")),
  )
  let reencoded = match decoded.to_cdr_bytes() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(reencoded, encoded)
  let vendor_encoded = match
    endpoint.to_cdr_bytes_with_vendor(VendorId::new(1, 15)) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let vendor_parameters = match ParameterList::from_cdr_bytes(vendor_encoded) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let mut protocol_found = false
  let mut vendor_found = false
  for parameter in vendor_parameters.values() {
    if parameter.id() == PID_PROTOCOL_VERSION {
      protocol_found = true
      assert_eq(parameter.value(), b"\x02\x03\x00\x00")
    }
    if parameter.id() == PID_VENDOR_ID {
      vendor_found = true
      assert_eq(parameter.value(), b"\x01\x0F\x00\x00")
    }
  }
  assert_true(protocol_found)
  assert_true(vendor_found)
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
test "SEDP extracts an endpoint GUID from key-only data" {
  let prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let endpoint_id = @rtps.EntityId::new(b"pub", 0x02).unwrap()
  let endpoint_guid = @rtps.Guid::new(prefix, endpoint_id)
  let reader_id = @rtps.EntityId::new(b"rea", 0xC7).unwrap()
  let writer_id = @rtps.EntityId::new(b"wri", 0xC2).unwrap()
  let data = @rtps.DataSubmessage::new(reader_id, writer_id, 2L, b"")
    .with_key(endpoint_guid.to_bytes())
  assert_eq(
    @rtps.SedpEndpointData::endpoint_guid_from_key_data(data).unwrap(),
    endpoint_guid,
  )
}

///|
test "SEDP builds an endpoint dispose DATA sample" {
  let endpoint_guid = sedp_test_guid(0xC2).unwrap()
  let endpoint = SedpEndpointData::new(
    SedpEndpointKind::Publication,
    endpoint_guid,
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  let reader_id = EntityId::new(b"rea", 0xC7).unwrap()
  let writer_id = EntityId::new(b"wri", 0xC2).unwrap()
  let data = endpoint.to_dispose_data_submessage(reader_id, writer_id, 4L)
  assert_true((data.flags() & DATA_FLAG_KEY) != 0x00)
  assert_eq(
    data.status_info(),
    Ok(Some(STATUS_INFO_DISPOSED | STATUS_INFO_UNREGISTERED)),
  )
  assert_eq(
    SedpEndpointData::endpoint_guid_from_key_data(data).unwrap(),
    endpoint_guid,
  )
}

///|
test "SEDP endpoint type hash is optional and validates malformed user data" {
  let endpoint_guid = sedp_test_guid(0xC2).unwrap()
  let endpoint = SedpEndpointData::new(
    SedpEndpointKind::Publication,
    endpoint_guid,
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  assert_eq(endpoint.type_hash(), Ok(None))
  endpoint.add_parameter(qos_user_data(b"typehash="))
  assert_true(endpoint.type_hash() is Err(_))
  endpoint.add_parameter(qos_user_data(Bytes::from_array([0xFF])))
  assert_true(endpoint.type_hash() is Err(_))
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

///|
test "SEDP reads basic QoS and checks offered compatibility" {
  let prefix = match
    GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match EntityId::new(b"pub", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let reader_id = match EntityId::new(b"sub", 0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let publication = match
    SedpEndpointData::new(
      SedpEndpointKind::Publication,
      Guid::new(prefix, writer_id),
      "rt/chatter",
      "std_msgs::msg::dds_::String_",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  publication.add_parameter(qos_reliability(RELIABILITY_RELIABLE, 0, 0))
  publication.add_parameter(qos_durability(DURABILITY_TRANSIENT_LOCAL))
  publication.add_parameter(qos_history(HISTORY_KEEP_LAST, 1))
  let subscription = match
    SedpEndpointData::new(
      SedpEndpointKind::Subscription,
      Guid::new(prefix, reader_id),
      "rt/chatter",
      "std_msgs::msg::dds_::String_",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  subscription.add_parameter(qos_reliability(RELIABILITY_BEST_EFFORT, 0, 0))
  subscription.add_parameter(qos_durability(DURABILITY_VOLATILE))
  subscription.add_parameter(qos_history(HISTORY_KEEP_LAST, 1))
  let qos = match publication.qos() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(qos.reliability(), RELIABILITY_RELIABLE)
  assert_eq(qos.durability(), DURABILITY_TRANSIENT_LOCAL)
  assert_true(
    match publication.qos_compatible_with(subscription) {
      Ok(value) => value
      Err(message) => fail(message)
    },
  )
  assert_true(subscription.qos_compatible_with(publication) is Err(_))
}

///|
test "SEDP matches deadline and liveliness offered/requested QoS" {
  let publication = SedpEndpointData::new(
    SedpEndpointKind::Publication,
    sedp_test_guid(0xC2).unwrap(),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  publication.add_parameter(qos_deadline(1, 0U))
  publication.add_parameter(
    qos_liveliness(LIVELINESS_MANUAL_BY_PARTICIPANT, 3, 0U),
  )

  let compatible_subscription = SedpEndpointData::new(
    SedpEndpointKind::Subscription,
    sedp_test_guid(0xC7).unwrap(),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  compatible_subscription.add_parameter(qos_deadline(2, 0U))
  compatible_subscription.add_parameter(
    qos_liveliness(LIVELINESS_AUTOMATIC, 4, 0U),
  )
  assert_true(
    publication.qos_compatible_with(compatible_subscription).unwrap(),
  )

  let deadline_too_strict = SedpEndpointData::new(
    SedpEndpointKind::Subscription,
    sedp_test_guid(0xC7).unwrap(),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  deadline_too_strict.add_parameter(qos_deadline(0, 500_000_000U))
  deadline_too_strict.add_parameter(
    qos_liveliness(LIVELINESS_AUTOMATIC, 4, 0U),
  )
  assert_false(
    publication.qos_compatible_with(deadline_too_strict).unwrap(),
  )

  let liveliness_too_strict = SedpEndpointData::new(
    SedpEndpointKind::Subscription,
    sedp_test_guid(0xC7).unwrap(),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  liveliness_too_strict.add_parameter(qos_deadline(2, 0U))
  liveliness_too_strict.add_parameter(
    qos_liveliness(LIVELINESS_MANUAL_BY_TOPIC, 4, 0U),
  )
  assert_false(
    publication.qos_compatible_with(liveliness_too_strict).unwrap(),
  )

  let lease_too_strict = SedpEndpointData::new(
    SedpEndpointKind::Subscription,
    sedp_test_guid(0xC7).unwrap(),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  lease_too_strict.add_parameter(qos_deadline(2, 0U))
  lease_too_strict.add_parameter(
    qos_liveliness(LIVELINESS_AUTOMATIC, 2, 0U),
  )
  assert_false(publication.qos_compatible_with(lease_too_strict).unwrap())
}

///|
test "SEDP rejects malformed deadline and liveliness QoS" {
  let endpoint = SedpEndpointData::new(
    SedpEndpointKind::Publication,
    sedp_test_guid(0xC2).unwrap(),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  endpoint.add_parameter(Parameter::new(PID_DEADLINE, b"\x00\x00\x00\x00"))
  assert_true(endpoint.qos() is Err(_))

  let liveliness_endpoint = SedpEndpointData::new(
    SedpEndpointKind::Publication,
    sedp_test_guid(0xC2).unwrap(),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  liveliness_endpoint.add_parameter(
    Parameter::new(PID_LIVELINESS, b"\x03\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"),
  )
  assert_true(liveliness_endpoint.qos() is Err(_))
}

///|
test "SEDP rejects invalid reliability, durability, and history QoS" {
  let invalid_parameters = [
    qos_reliability(0U, 0, 0),
    Parameter::new(PID_RELIABILITY, b"\x02\x00\x00\x00"),
    qos_durability(4U),
    qos_history(2U, 1),
    qos_history(HISTORY_KEEP_LAST, 0),
  ]
  for parameter in invalid_parameters {
    let endpoint = SedpEndpointData::new(
      SedpEndpointKind::Publication,
      sedp_test_guid(0xC2).unwrap(),
      "rt/chatter",
      "std_msgs::msg::dds_::String_",
    ).unwrap()
    endpoint.add_parameter(parameter)
    assert_true(endpoint.qos() is Err(_))
  }
}

///|
test "SEDP omitted reliability defaults depend on endpoint kind" {
  let publication = SedpEndpointData::new(
    SedpEndpointKind::Publication,
    sedp_test_guid(0xC2).unwrap(),
    "rr/add_two_intsReply",
    "example_interfaces::srv::dds_::AddTwoInts_Response_",
  ).unwrap()
  publication.add_parameter(qos_durability(DURABILITY_VOLATILE))
  assert_eq(
    publication.qos().unwrap().reliability(),
    RELIABILITY_RELIABLE,
  )

  let subscription = SedpEndpointData::new(
    SedpEndpointKind::Subscription,
    sedp_test_guid(0xC7).unwrap(),
    "rq/add_two_intsRequest",
    "example_interfaces::srv::dds_::AddTwoInts_Request_",
  ).unwrap()
  subscription.add_parameter(qos_durability(DURABILITY_VOLATILE))
  assert_eq(
    subscription.qos().unwrap().reliability(),
    RELIABILITY_BEST_EFFORT,
  )
}

///|
test "SEDP matches endpoints only when data representations overlap" {
  let publication = SedpEndpointData::new(
    SedpEndpointKind::Publication,
    sedp_test_guid(0xC2).unwrap(),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  publication.add_parameter(
    qos_data_representation([DATA_REPRESENTATION_XCDR2]),
  )
  let subscription_xcdr2 = SedpEndpointData::new(
    SedpEndpointKind::Subscription,
    sedp_test_guid(0xC7).unwrap(),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  subscription_xcdr2.add_parameter(
    qos_data_representation([DATA_REPRESENTATION_XCDR2]),
  )
  assert_true(publication.qos_compatible_with(subscription_xcdr2).unwrap())

  let subscription_xcdr1 = SedpEndpointData::new(
    SedpEndpointKind::Subscription,
    sedp_test_guid(0xC7).unwrap(),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  subscription_xcdr1.add_parameter(
    qos_data_representation([DATA_REPRESENTATION_XCDR1]),
  )
  assert_false(publication.qos_compatible_with(subscription_xcdr1).unwrap())
}

///|
test "SEDP rejects malformed data representation sequences" {
  let endpoint = SedpEndpointData::new(
    SedpEndpointKind::Publication,
    sedp_test_guid(0xC2).unwrap(),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  endpoint.add_parameter(
    Parameter::new(PID_DATA_REPRESENTATION, b"\x02\x00\x00\x00\x00\x00"),
  )
  assert_true(endpoint.qos() is Err(_))
}

///|
test "SEDP rejects overflowing variable-length fields" {
  let oversized_length = b"\xFC\xFF\xFF\x7F"
  let endpoint = SedpEndpointData::new(
    SedpEndpointKind::Publication,
    sedp_test_guid(0xC2).unwrap(),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  endpoint.add_parameter(
    Parameter::new(PID_DATA_REPRESENTATION, oversized_length),
  )
  assert_true(endpoint.qos() is Err(_))

  let endpoint = SedpEndpointData::new(
    SedpEndpointKind::Publication,
    sedp_test_guid(0xC2).unwrap(),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  let parameters = endpoint.to_parameter_list().unwrap()
  parameters.add(Parameter::new(PID_USER_DATA, oversized_length))
  assert_true(
    SedpEndpointData::from_parameter_list(
      SedpEndpointKind::Publication,
      parameters,
    ) is Err(_),
  )

  let parameters = ParameterList::new()
  parameters.add(
    Parameter::new(PID_ENDPOINT_GUID, sedp_test_guid(0xC2).unwrap().to_bytes()),
  )
  parameters.add(Parameter::new(PID_TOPIC_NAME, oversized_length))
  assert_true(
    SedpEndpointData::from_parameter_list(
      SedpEndpointKind::Publication,
      parameters,
    ) is Err(_),
  )
}

///|
test "SEDP subscription advertises that it does not expect inline QoS" {
  let endpoint_guid = match sedp_test_guid(0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let endpoint = match
    SedpEndpointData::new(
      SedpEndpointKind::Subscription,
      endpoint_guid,
      "rt/chatter",
      "std_msgs::msg::dds_::String_",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let parameters = match endpoint.to_parameter_list() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let mut expects_inline_qos_found = false
  for parameter in parameters.values() {
    if parameter.id() == PID_EXPECTS_INLINE_QOS {
      expects_inline_qos_found = true
      assert_eq(parameter.value(), b"\x00\x00\x00\x00")
    }
  }
  assert_true(expects_inline_qos_found)
}

///|
test "SEDP does not duplicate direction-specific standard parameters" {
  let endpoint_guid = match sedp_test_guid(0xC2) {
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
    Ok(value) => value
    Err(message) => fail(message)
  }
  endpoint.add_parameter(qos_type_max_size_serialized(1024))
  let parameters = match endpoint.to_parameter_list() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let mut count = 0
  for parameter in parameters.values() {
    if parameter.id() == PID_TYPE_MAX_SIZE_SERIALIZED {
      count += 1
      assert_eq(parameter.value(), b"\x00\x04\x00\x00")
    }
  }
  assert_eq(count, 1)
}

///|
test "SEDP DATA accepts an unencapsulated ParameterList" {
  let endpoint_guid = sedp_test_guid(0xC2).unwrap()
  let endpoint = SedpEndpointData::new(
    SedpEndpointKind::Publication,
    endpoint_guid,
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  let encoded = endpoint.to_cdr_bytes().unwrap()
  let reader_id = EntityId::new(b"rdr", 0xC7).unwrap()
  let writer_id = EntityId::new(b"wrt", 0xC2).unwrap()
  let data = DataSubmessage::new(
    reader_id,
    writer_id,
    1L,
    encoded[4:].to_owned(),
  )
  let decoded = SedpEndpointData::from_data_submessage(
    SedpEndpointKind::Publication,
    data,
  ).unwrap()
  assert_eq(decoded.endpoint_guid(), endpoint_guid)
  assert_eq(decoded.topic_name(), "rt/chatter")
}
