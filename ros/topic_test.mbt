///|
test "ROS topic descriptor maps names into SEDP identity" {
  let topic = match RosTopic::new("/chatter", "std_msgs", "msg", "String") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(topic.ros_name(), "/chatter")
  assert_eq(topic.dds_name(), "rt/chatter")
  assert_eq(topic.dds_type_name(), "std_msgs::msg::dds_::String_")
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let entity_id = match @rtps.EntityId::new(b"abc", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let endpoint = match
    topic.to_sedp(
      @rtps.SedpEndpointKind::Publication,
      @rtps.Guid::new(prefix, entity_id),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(endpoint.topic_name(), "rt/chatter")
  assert_eq(endpoint.type_name(), "std_msgs::msg::dds_::String_")
  let default_qos = match endpoint.qos() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(default_qos.reliability(), @rtps.RELIABILITY_BEST_EFFORT)
  assert_eq(default_qos.depth(), 1)
}

///|
test "ROS topic descriptor applies explicit reliable QoS" {
  let topic = match RosTopic::new("/chatter", "std_msgs", "msg", "String") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let entity_id = match @rtps.EntityId::new(b"pub", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let endpoint = match
    topic.to_sedp_with_qos(
      @rtps.SedpEndpointKind::Publication,
      @rtps.Guid::new(prefix, entity_id),
      @rtps.SedpQos::new(
        @rtps.RELIABILITY_RELIABLE,
        @rtps.DURABILITY_VOLATILE,
        @rtps.HISTORY_KEEP_LAST,
        10,
      ),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let qos = match endpoint.qos() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(qos.reliability(), @rtps.RELIABILITY_RELIABLE)
  assert_eq(qos.history(), @rtps.HISTORY_KEEP_LAST)
  assert_eq(qos.depth(), 10)
  assert_true(
    topic.to_sedp_with_qos(
      @rtps.SedpEndpointKind::Publication,
      @rtps.Guid::new(prefix, entity_id),
      @rtps.SedpQos::new(99U, 0U, 0U, 1),
    )
    is Err(_),
  )
}
