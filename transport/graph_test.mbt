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
  graph.ingest(DiscoveryEvent::Participant(participant))
  graph.ingest(DiscoveryEvent::Participant(participant))
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
  graph.ingest(DiscoveryEvent::Publication(publication))
  let matched = graph.find_publications(
    "rt/chatter", "std_msgs::msg::dds_::String_",
  )
  assert_eq(graph.publication_count(), 1)
  assert_eq(matched.length(), 1)
  assert_eq(matched[0].unicast_locators()[0].port(), 9000U)
  assert_eq(graph.find_subscriptions("rt/chatter", "missing").length(), 0)
}
