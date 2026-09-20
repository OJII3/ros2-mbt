///|
fn discovery_topic_test_guid(kind : Byte) -> @rtps.Guid {
  let prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let entity_id = @rtps.EntityId::new(b"abc", kind).unwrap()
  @rtps.Guid::new(prefix, entity_id)
}

///|
fn discovery_topic_test_parameter(
  endpoint : @rtps.SedpEndpointData,
  id : UInt16,
) -> @rtps.Parameter {
  for parameter in endpoint.extra_parameters() {
    if parameter.id() == id {
      return parameter
    }
  }
  endpoint.extra_parameters()[0]
}

///|
test "ROS discovery topic uses the standard DDS identity and writer QoS" {
  let endpoint = match
    ros_discovery_info_to_sedp(
      @rtps.SedpEndpointKind::Publication,
      discovery_topic_test_guid(0xC2),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(endpoint.topic_name(), "ros_discovery_info")
  assert_eq(
    endpoint.type_name(),
    "rmw_dds_common::msg::dds_::ParticipantEntitiesInfo_",
  )
  assert_eq(endpoint.type_hash(), Ok(Some(ROS_DISCOVERY_INFO_TYPE_HASH)))
  assert_eq(
    discovery_topic_test_parameter(endpoint, @rtps.PID_RELIABILITY).value(),
    b"\x02\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
  )
  assert_eq(
    discovery_topic_test_parameter(endpoint, @rtps.PID_DURABILITY).value(),
    b"\x01\x00\x00\x00",
  )
  assert_eq(
    discovery_topic_test_parameter(endpoint, @rtps.PID_HISTORY).value(),
    b"\x00\x00\x00\x00\x01\x00\x00\x00",
  )
  assert_eq(
    discovery_topic_test_parameter(endpoint, @rtps.PID_DATA_REPRESENTATION).value(),
    b"\x01\x00\x00\x00\x00\x00",
  )
}

///|
test "ROS discovery topic uses keep-all for the reader" {
  let endpoint = match
    ros_discovery_info_to_sedp(
      @rtps.SedpEndpointKind::Subscription,
      discovery_topic_test_guid(0xC7),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(
    discovery_topic_test_parameter(endpoint, @rtps.PID_HISTORY).value(),
    b"\x01\x00\x00\x00\x01\x00\x00\x00",
  )
}
