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
  assert_eq(default_qos.reliability(), @rtps.RELIABILITY_RELIABLE)
  assert_eq(default_qos.durability(), @rtps.DURABILITY_VOLATILE)
  assert_eq(default_qos.history(), @rtps.HISTORY_KEEP_LAST)
  assert_eq(default_qos.depth(), 10)
  assert_eq(default_qos.deadline_seconds(), 0x7FFFFFFF)
  assert_eq(default_qos.deadline_fraction(), 0xFFFFFFFFU)
  assert_eq(default_qos.liveliness(), @rtps.LIVELINESS_AUTOMATIC)
  assert_eq(default_qos.liveliness_lease_seconds(), 0x7FFFFFFF)
  assert_eq(default_qos.liveliness_lease_fraction(), 0xFFFFFFFFU)
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

///|
test "ROS topic descriptor advertises deadline and liveliness QoS" {
  let topic = RosTopic::new("/chatter", "std_msgs", "msg", "String").unwrap()
  let prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let entity_id = @rtps.EntityId::new(b"pub", 0xC2).unwrap()
  let qos = @rtps.SedpQos::default()
    .with_deadline(2, 500_000_000U).unwrap()
    .with_liveliness(
      @rtps.LIVELINESS_MANUAL_BY_TOPIC,
      5,
      250_000_000U,
    ).unwrap()
  let endpoint = topic.to_sedp_with_qos(
    @rtps.SedpEndpointKind::Publication,
    @rtps.Guid::new(prefix, entity_id),
    qos,
  ).unwrap()
  let decoded_qos = endpoint.qos().unwrap()
  assert_eq(decoded_qos.deadline_seconds(), 2)
  assert_eq(decoded_qos.deadline_fraction(), 0x80000000U)
  assert_eq(decoded_qos.liveliness(), @rtps.LIVELINESS_MANUAL_BY_TOPIC)
  assert_eq(decoded_qos.liveliness_lease_seconds(), 5)
  assert_eq(decoded_qos.liveliness_lease_fraction(), 0x40000000U)
  assert_true(
    qos.with_deadline(0, 1_000_000_000U) is Err(_),
  )
  assert_true(
    qos.with_liveliness(3U, 1, 0U) is Err(_),
  )
}

///|
test "ROS topic descriptor advertises its supported data representation" {
  let topic = RosTopic::new("/chatter", "std_msgs", "msg", "String").unwrap()
  let prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let entity_id = @rtps.EntityId::new(b"pub", 0xC2).unwrap()
  let qos = @rtps.SedpQos::new(
    @rtps.RELIABILITY_RELIABLE,
    @rtps.DURABILITY_VOLATILE,
    @rtps.HISTORY_KEEP_LAST,
    10,
  ).with_data_representation([@rtps.DATA_REPRESENTATION_XCDR1])
  let endpoint = topic.to_sedp_with_qos(
    @rtps.SedpEndpointKind::Publication,
    @rtps.Guid::new(prefix, entity_id),
    qos,
  ).unwrap()
  let decoded_qos = endpoint.qos().unwrap()
  assert_eq(
    decoded_qos.data_representation(),
    [@rtps.DATA_REPRESENTATION_XCDR1],
  )
  assert_true(
    topic.to_sedp_with_qos(
      @rtps.SedpEndpointKind::Publication,
      @rtps.Guid::new(prefix, entity_id),
      qos.with_data_representation([@rtps.DATA_REPRESENTATION_XCDR2]),
    ) is Err(_),
  )
  assert_true(
    topic.to_sedp_with_qos(
      @rtps.SedpEndpointKind::Publication,
      @rtps.Guid::new(prefix, entity_id),
      qos.with_data_representation([]),
    ) is Err(_),
  )
}

///|
test "ROS topic descriptor advertises its RIHS01 type hash" {
  let topic = RosTopic::new("/chatter", "std_msgs", "msg", "String").unwrap()
  let prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let entity_id = @rtps.EntityId::new(b"pub", 0xC2).unwrap()
  let type_hash =
    "RIHS01_df668c740482bbd48fb39d76a70dfd4bd59db1288021743503259e948f6b1a18"
  let endpoint = topic.to_sedp_with_qos_and_type_hash(
    @rtps.SedpEndpointKind::Publication,
    @rtps.Guid::new(prefix, entity_id),
    @rtps.SedpQos::default(),
    type_hash,
  ).unwrap()
  let expected = @rtps.qos_user_data_type_hash(type_hash).value()
  let mut found = false
  for parameter in endpoint.extra_parameters() {
    if parameter.id() == @rtps.PID_USER_DATA {
      found = true
      assert_eq(parameter.value(), expected)
    }
  }
  assert_true(found)
}
