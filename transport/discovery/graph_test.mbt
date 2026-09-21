///|
test "discovery graph upserts and matches endpoints" {
  let graph = DiscoveryGraph::new()
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let participant_id = match @rtps.EntityId::new(b"abc", 0xC1) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let participant_guid = @rtps.Guid::new(prefix, participant_id)
  let participant = @rtps.SpdpParticipantData::new(
    participant_guid,
    @rtps.VendorId::new(1, 15),
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER,
  )
  graph.ingest(@wire.DiscoveryEvent::Participant(participant))
  graph.ingest(@wire.DiscoveryEvent::Participant(participant))
  assert_eq(graph.participant_count(), 1)

  let publication_id = match @rtps.EntityId::new(b"pub", 0x02) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let publication = match
    @rtps.SedpEndpointData::new(
      @rtps.SedpEndpointKind::Publication,
      @rtps.Guid::new(prefix, publication_id),
      "rt/chatter",
      "std_msgs::msg::dds_::String_",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let locator = match @rtps.Locator::udp_v4(b"\x7F\x00\x00\x01", 9000) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  publication.add_unicast_locator(locator)
  graph.ingest(@wire.DiscoveryEvent::Publication(publication))
  let matched = graph.find_publications(
    "rt/chatter", "std_msgs::msg::dds_::String_",
  )
  assert_eq(graph.publication_count(), 1)
  assert_eq(matched.length(), 1)
  assert_eq(matched[0].unicast_locators()[0].port(), 9000U)
  assert_eq(graph.find_subscriptions("rt/chatter", "missing").length(), 0)
  graph.ingest(
    @wire.DiscoveryEvent::EndpointRemoved(
      @rtps.SedpEndpointKind::Publication,
      publication.endpoint_guid(),
    ),
  )
  assert_eq(graph.publication_count(), 0)
}

///|
test "discovery graph removes a participant and its endpoints" {
  let prefix = @rtps.GuidPrefix::from_array([
    12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23,
  ]).unwrap()
  let participant_guid = @rtps.Guid::new(
    prefix,
    @rtps.EntityId::new(b"prt", 0xC1).unwrap(),
  )
  let participant = @rtps.SpdpParticipantData::new(
    participant_guid,
    @rtps.VendorId::new(1, 15),
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER,
  )
  let publication = @rtps.SedpEndpointData::new(
    @rtps.SedpEndpointKind::Publication,
    @rtps.Guid::new(prefix, @rtps.EntityId::new(b"pub", 0xC2).unwrap()),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  let subscription = @rtps.SedpEndpointData::new(
    @rtps.SedpEndpointKind::Subscription,
    @rtps.Guid::new(prefix, @rtps.EntityId::new(b"sub", 0xC7).unwrap()),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  let graph = DiscoveryGraph::new()
  graph.ingest(@wire.DiscoveryEvent::Participant(participant))
  graph.ingest(@wire.DiscoveryEvent::Publication(publication))
  graph.ingest(@wire.DiscoveryEvent::Subscription(subscription))
  let info = @ros.ParticipantEntitiesInfo::new(
    @ros.Gid::from_guid(participant_guid),
  )
  let info_node = @ros.NodeEntitiesInfo::new("/demo", "talker").unwrap()
  info_node.add_writer_gid(@ros.Gid::from_guid(publication.endpoint_guid()))
  info.add_node(info_node)
  graph.ingest_ros_discovery_info(info)
  assert_eq(
    graph.ros_participants()[0].node_entities_info_seq()[0]
    .writer_gid_seq()
    .length(),
    1,
  )
  graph.ingest(
    @wire.DiscoveryEvent::EndpointRemoved(
      @rtps.SedpEndpointKind::Publication,
      publication.endpoint_guid(),
    ),
  )
  assert_eq(
    graph.ros_participants()[0].node_entities_info_seq()[0]
    .writer_gid_seq()
    .length(),
    0,
  )
  assert_eq(graph.ros_participant_count(), 1)
  graph.ingest(@wire.DiscoveryEvent::ParticipantRemoved(participant_guid))
  assert_eq(graph.participant_count(), 0)
  assert_eq(graph.publication_count(), 0)
  assert_eq(graph.subscription_count(), 0)
  assert_eq(graph.ros_participant_count(), 0)
}

///|
test "discovery graph upserts ROS participant entities" {
  let gid = match @ros.Gid::new(b"0123456789abcdef") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let first = @ros.ParticipantEntitiesInfo::new(gid)
  let first_node = match @ros.NodeEntitiesInfo::new("/demo", "talker") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  first.add_node(first_node)
  let second = @ros.ParticipantEntitiesInfo::new(gid)
  let second_node = match @ros.NodeEntitiesInfo::new("/demo", "listener") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  second.add_node(second_node)
  let graph = DiscoveryGraph::new()
  graph.ingest_ros_discovery_info(first)
  graph.ingest_ros_discovery_info(second)
  assert_eq(graph.ros_participant_count(), 1)
  assert_eq(
    graph.ros_participants()[0].node_entities_info_seq()[0].node_name(),
    "listener",
  )
}

///|
test "discovery graph filters publications by basic QoS" {
  let graph = DiscoveryGraph::new()
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let publication_id = match @rtps.EntityId::new(b"pub", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let subscription_id = match @rtps.EntityId::new(b"sub", 0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let publication = match
    @rtps.SedpEndpointData::new(
      @rtps.SedpEndpointKind::Publication,
      @rtps.Guid::new(prefix, publication_id),
      "rt/chatter",
      "std_msgs::msg::dds_::String_",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  publication.add_parameter(
    @rtps.qos_reliability(@rtps.RELIABILITY_RELIABLE, 0, 0),
  )
  let subscription = match
    @rtps.SedpEndpointData::new(
      @rtps.SedpEndpointKind::Subscription,
      @rtps.Guid::new(prefix, subscription_id),
      "rt/chatter",
      "std_msgs::msg::dds_::String_",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  subscription.add_parameter(
    @rtps.qos_reliability(@rtps.RELIABILITY_RELIABLE, 0, 0),
  )
  graph.ingest(@wire.DiscoveryEvent::Publication(publication))
  let matched = match graph.find_compatible_publications(subscription) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(matched.length(), 1)
}
