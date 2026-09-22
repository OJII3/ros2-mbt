///|
async test "discovery service retransmits SEDP samples requested by ACKNACK" {
  let local_prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let remote_prefix = @rtps.GuidPrefix::from_array([
    11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
  ]).unwrap()
  let participant_id = @rtps.EntityId::new(b"prt", 0xC1).unwrap()
  let spdp_reader = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
  ).unwrap()
  let spdp_writer = @rtps.EntityId::new(
    b"\x00\x01\x00",
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
    @rtps.BUILTIN_ENDPOINT_PUBLICATIONS_DETECTOR,
  )
  let receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  defer receiver.close()
  let receiver_locator = @rtps.Locator::udp_v4(
    b"\x7F\x00\x00\x01",
    receiver.local_addr().port().reinterpret_as_uint(),
  ).unwrap()
  remote_participant.add_metatraffic_unicast(receiver_locator)
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  defer sender.close()
  let service = @discovery.DiscoveryService::new(
    @discovery.DiscoverySession::new(
      sender,
      local_participant,
      spdp_reader,
      spdp_writer,
      receiver.local_addr(),
      1L,
    ).unwrap(),
  )
  let endpoint = @rtps.SedpEndpointData::new(
    Publication,
    @rtps.Guid::new(local_prefix, @rtps.EntityId::new(b"pub", 0xC2).unwrap()),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  service.announce_sedp_once(endpoint, remote_participant).unwrap()
  let (initial_data, _) = test_receive(() => receiver.receive_sedp(Publication)).unwrap()
  assert_eq(initial_data.topic_name(), "rt/chatter")
  ignore(test_receive(() => receiver.receive_heartbeat()).unwrap())
  let acknack = @rtps.AckNackSubmessage::new(
    @rtps.SedpEndpointKind::Publication.builtin_reader_id(),
    @rtps.SedpEndpointKind::Publication.builtin_writer_id(),
    1L,
    1U,
    [0x80000000U],
    1U,
  ).unwrap()
  receiver
  .send_acknack(
    acknack,
    remote_prefix,
    @rtps.VendorId::new(1, 15),
    service.session.socket.local_addr(),
  )
  .unwrap()
  receiver
  .send_spdp(
    remote_participant,
    spdp_reader,
    spdp_writer,
    1L,
    service.session.socket.local_addr(),
  )
  .unwrap()
  match test_receive(() => service.receive_once()).unwrap().1 {
    Participant(participant) =>
      assert_eq(participant.participant_guid().prefix(), remote_prefix)
    Publication(_) => fail("expected the follow-up SPDP event")
    Subscription(_) => fail("expected the follow-up SPDP event")
    EndpointRemoved(_, _) => fail("expected the follow-up SPDP event")
    ParticipantRemoved(_) => fail("expected the follow-up SPDP event")
  }
  let (retransmitted_message, _) = test_receive(() => receiver.receive_message()).unwrap()
  assert_eq(
    retransmitted_message.destination_guid_prefix(),
    Ok(Some(remote_prefix)),
  )
  let retransmitted = @rtps.DataSubmessage::from_submessage(
    retransmitted_message.submessages()[1],
  ).unwrap()
  assert_eq(retransmitted.writer_sequence_number(), 1L)
  let decoded = @rtps.SedpEndpointData::from_data_submessage(
    Publication,
    retransmitted,
  ).unwrap()
  assert_eq(decoded.topic_name(), "rt/chatter")
  service.close()
  receiver.close()
}
