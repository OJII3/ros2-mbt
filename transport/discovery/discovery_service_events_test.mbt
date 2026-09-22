///|
async test "discovery service ingests received participant events" {
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let participant_id = match
    @rtps.EntityId::new(b"abc", @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(prefix, participant_id),
    @rtps.VendorId::new(1, 15),
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR,
  )
  let reader_id = match
    @rtps.EntityId::new(
      b"\x00\x01\x00",
      @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match
    @rtps.EntityId::new(
      b"\x00\x01\x00",
      @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  defer receiver.close()
  let receiver_address = receiver.local_addr()
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  defer sender.close()
  let session = match
    @discovery.DiscoverySession::new(
      receiver, participant, reader_id, writer_id, receiver_address, 1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let service = @discovery.DiscoveryService::new(session)
  match
    sender.send_spdp(participant, reader_id, writer_id, 1L, receiver_address) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (_, _) = match test_receive(() => service.receive_once()) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(service.graph().participant_count(), 1)
  service.close()
  sender.close()
}

///|
async test "discovery service resolves unspecified SEDP endpoint locators" {
  let local_prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let remote_prefix = @rtps.GuidPrefix::from_array([
    11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
  ]).unwrap()
  let participant_id = @rtps.EntityId::new(
    b"abc",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
  ).unwrap()
  let local_participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(local_prefix, participant_id),
    @rtps.VendorId::new(1, 15),
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER,
  )
  let remote_participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(remote_prefix, participant_id),
    @rtps.VendorId::new(1, 15),
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER,
  )
  remote_participant.add_default_unicast(
    @rtps.Locator::udp_v4(Bytes::from_array([0, 0, 0, 0]), 7411U).unwrap(),
  )
  remote_participant.add_default_unicast(
    @rtps.Locator::udp_v4(Bytes::from_array([127, 0, 0, 1]), 7411U).unwrap(),
  )
  remote_participant.add_default_unicast(
    @rtps.Locator::udp_v4(Bytes::from_array([192, 168, 1, 10]), 7411U).unwrap(),
  )
  let reader_id = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
  ).unwrap()
  let socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  defer socket.close()
  let receiver_address = socket.local_addr()
  let session = @discovery.DiscoverySession::new(
    socket, local_participant, reader_id, participant_id, receiver_address, 1L,
  ).unwrap()
  let service = @discovery.DiscoveryService::new(session)
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  defer sender.close()
  sender
  .send_spdp(
    remote_participant, reader_id, participant_id, 1L, receiver_address,
  )
  .unwrap()
  let (_, participant_event) = test_receive(() => service.receive_once()).unwrap()
  assert_true(participant_event is Participant(_))
  let endpoint = @rtps.SedpEndpointData::new(
    Subscription,
    @rtps.Guid::new(
      remote_prefix,
      @rtps.EntityId::new(b"\x00\x00\x02", 0x04).unwrap(),
    ),
    "ros_discovery_info",
    "rmw_dds_common::msg::dds_::ParticipantEntitiesInfo_",
  ).unwrap()
  endpoint.add_unicast_locator(
    @rtps.Locator::udp_v4(Bytes::from_array([0, 0, 0, 0]), 7002U).unwrap(),
  )
  sender
  .send_sedp(
    endpoint,
    @rtps.VendorId::new(1, 15),
    @rtps.SedpEndpointKind::Subscription.builtin_reader_id(),
    @rtps.SedpEndpointKind::Subscription.builtin_writer_id(),
    1L,
    receiver_address,
  )
  .unwrap()
  let (_, endpoint_event) = test_receive(() => service.receive_once()).unwrap()
  let normalized = match endpoint_event {
    Subscription(endpoint) => endpoint
    _ => fail("expected the normalized SEDP subscription")
  }
  assert_eq(normalized.unicast_locators(), [
    @rtps.Locator::udp_v4(Bytes::from_array([127, 0, 0, 1]), 7002U).unwrap(),
    @rtps.Locator::udp_v4(Bytes::from_array([192, 168, 1, 10]), 7002U).unwrap(),
  ])
  service.close()
  sender.close()
}

///|
async test "discovery service expires participants after the SPDP lease" {
  let local_prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let remote_prefix = @rtps.GuidPrefix::from_array([
    11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
  ]).unwrap()
  let participant_entity = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
  ).unwrap()
  let local_participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(local_prefix, participant_entity),
    @rtps.VendorId::new(1, 15),
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER,
  )
  let remote_participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(remote_prefix, participant_entity),
    @rtps.VendorId::new(1, 15),
    0,
    0,
    500_000_000U,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER,
  )
  let reader_id = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
  ).unwrap()
  let writer_id = participant_entity
  let socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  defer socket.close()
  let receiver_address = socket.local_addr()
  let session = @discovery.DiscoverySession::new(
    socket, local_participant, reader_id, writer_id, receiver_address, 1L,
  ).unwrap()
  let service = @discovery.DiscoveryService::new(session)
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  defer sender.close()
  sender
  .send_spdp(remote_participant, reader_id, writer_id, 1L, receiver_address)
  .unwrap()
  let (_, first_event) = test_receive(() => service.receive_once()).unwrap()
  assert_true(first_event is Participant(_))
  assert_eq(service.graph().participant_count(), 1)
  let publication = @rtps.SedpEndpointData::new(
    Publication,
    @rtps.Guid::new(remote_prefix, @rtps.EntityId::new(b"pub", 0xC2).unwrap()),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  sender
  .send_sedp(
    publication,
    @rtps.VendorId::new(1, 15),
    @rtps.SedpEndpointKind::Publication.builtin_reader_id(),
    @rtps.SedpEndpointKind::Publication.builtin_writer_id(),
    1L,
    receiver_address,
  )
  .unwrap()
  let (_, publication_event) = test_receive(() => service.receive_once()).unwrap()
  assert_true(publication_event is Publication(_))
  assert_eq(service.graph().publication_count(), 1)

  @async.sleep(300)
  sender
  .send_spdp(remote_participant, reader_id, writer_id, 2L, receiver_address)
  .unwrap()
  let (_, refresh_event) = test_receive(() => service.receive_once()).unwrap()
  assert_true(refresh_event is Participant(_))
  let before_expiry = @async.with_timeout_opt(300, async fn() {
    test_receive(() => service.receive_once())
  })
  assert_true(before_expiry is None)

  let (_, event) = test_receive(() => service.receive_once()).unwrap()
  match event {
    ParticipantRemoved(guid) =>
      assert_eq(guid, remote_participant.participant_guid())
    _ => fail("expected the expired participant removal")
  }
  assert_eq(service.graph().participant_count(), 0)
  assert_eq(service.graph().publication_count(), 0)
  service.close()
  sender.close()
}

///|
