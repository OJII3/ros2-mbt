///|
async test "discovery accepts GUIDPREFIX_UNKNOWN as an all-participants destination" {
  let local_prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let remote_prefix = @rtps.GuidPrefix::from_array([
    11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
  ]).unwrap()
  let other_prefix = @rtps.GuidPrefix::from_array([
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  ]).unwrap()
  let participant_writer = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
  ).unwrap()
  let participant_reader = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
  ).unwrap()
  let local_participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(local_prefix, participant_writer),
    @rtps.VendorId::new(1, 15),
    0U,
    60,
    0U,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR |
    @rtps.BUILTIN_ENDPOINT_PUBLICATIONS_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PUBLICATIONS_DETECTOR |
    @rtps.BUILTIN_ENDPOINT_SUBSCRIPTIONS_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_SUBSCRIPTIONS_DETECTOR,
  )
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let session = DiscoverySession::new(
    receiver,
    local_participant,
    participant_reader,
    participant_writer,
    sender.local_addr(),
    1L,
  ).unwrap()
  let endpoint_writer = @rtps.EntityId::new(b"pub", 0x03).unwrap()
  let publication = @rtps.SedpEndpointData::new(
    @rtps.SedpEndpointKind::Publication,
    @rtps.Guid::new(remote_prefix, endpoint_writer),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  let kind = @rtps.SedpEndpointKind::Publication
  let publication_message = publication
    .to_message(
      @rtps.VendorId::new(1, 15),
      kind.builtin_reader_id(),
      kind.builtin_writer_id(),
      1L,
    )
    .unwrap()
  sender
  .send_message(
    publication_message.with_destination_guid_prefix(other_prefix),
    session.socket.local_addr(),
  )
  .unwrap()
  sender
  .send_message(
    publication_message.with_destination_guid_prefix(
      @rtps.GuidPrefix::from_array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]).unwrap(),
    ),
    session.socket.local_addr(),
  )
  .unwrap()
  let (event, _) = session.receive_once().unwrap()
  match event {
    DiscoveryEvent::Publication(decoded) => {
      assert_eq(decoded.topic_name(), "rt/chatter")
      assert_eq(decoded.type_name(), "std_msgs::msg::dds_::String_")
    }
    _ => fail("expected the SEDP publication addressed to all participants")
  }
  session.close()
  sender.close()
}

///|
async test "discovery session repeats SPDP announcements" {
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
  let participant_guid = @rtps.Guid::new(prefix, participant_id)
  let participant = @rtps.SpdpParticipantData::new(
    participant_guid,
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
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let session = match
    DiscoverySession::new(
      sender,
      participant,
      reader_id,
      writer_id,
      receiver.local_addr(),
      1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match session.announce_n(1, 2) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  assert_eq(session.next_sequence_number(), 3L)
  let (first, source) = match receiver.receive_discovery() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (second, _) = match receiver.receive_discovery() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match first {
    DiscoveryEvent::Participant(decoded) =>
      assert_eq(decoded.to_cdr_bytes(), participant.to_cdr_bytes())
    DiscoveryEvent::Publication(_) => fail("expected an SPDP participant event")
    DiscoveryEvent::Subscription(_) =>
      fail("expected an SPDP participant event")
    DiscoveryEvent::EndpointRemoved(_, _) =>
      fail("expected an SPDP participant event")
    DiscoveryEvent::ParticipantRemoved(_) =>
      fail("expected an SPDP participant event")
  }
  match second {
    DiscoveryEvent::Participant(decoded) =>
      assert_eq(decoded.to_cdr_bytes(), participant.to_cdr_bytes())
    DiscoveryEvent::Publication(_) => fail("expected an SPDP participant event")
    DiscoveryEvent::Subscription(_) =>
      fail("expected an SPDP participant event")
    DiscoveryEvent::EndpointRemoved(_, _) =>
      fail("expected an SPDP participant event")
    DiscoveryEvent::ParticipantRemoved(_) =>
      fail("expected an SPDP participant event")
  }
  assert_eq(source.ip(), 0x7F000001U)
  receiver
  .send_data(
    @rtps.DataSubmessage::new(reader_id, writer_id, 3L, b"")
    .with_key(participant_guid.to_bytes())
    .with_status_info(@rtps.STATUS_INFO_DISPOSED),
    prefix,
    @rtps.VendorId::new(1, 15),
    session.socket.local_addr(),
  )
  .unwrap()
  let (removed, _) = session.receive_once().unwrap()
  match removed {
    DiscoveryEvent::ParticipantRemoved(removed_guid) =>
      assert_eq(removed_guid, participant_guid)
    DiscoveryEvent::Participant(_) => fail("expected an SPDP removal event")
    DiscoveryEvent::Publication(_) => fail("expected an SPDP removal event")
    DiscoveryEvent::Subscription(_) => fail("expected an SPDP removal event")
    DiscoveryEvent::EndpointRemoved(_, _) =>
      fail("expected an SPDP removal event")
  }
  match session.dispose_once() {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (outgoing_removed, _) = receiver.receive_discovery().unwrap()
  match outgoing_removed {
    DiscoveryEvent::ParticipantRemoved(removed_guid) =>
      assert_eq(removed_guid, participant_guid)
    DiscoveryEvent::Participant(_) => fail("expected an outgoing SPDP removal")
    DiscoveryEvent::Publication(_) => fail("expected an outgoing SPDP removal")
    DiscoveryEvent::Subscription(_) => fail("expected an outgoing SPDP removal")
    DiscoveryEvent::EndpointRemoved(_, _) =>
      fail("expected an outgoing SPDP removal")
  }
  session.close()
  receiver.close()
}

///|
async test "discovery session ignores DATA without payload or key" {
  let local_prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let remote_prefix = @rtps.GuidPrefix::from_array([
    11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
  ]).unwrap()
  let reader_id = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
  ).unwrap()
  let writer_id = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
  ).unwrap()
  let local_participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(local_prefix, writer_id),
    @rtps.VendorId::new(1, 15),
    0U,
    60,
    0U,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR,
  )
  let remote_participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(remote_prefix, writer_id),
    @rtps.VendorId::new(1, 15),
    0U,
    60,
    0U,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR,
  )
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let session = DiscoverySession::new(
    receiver,
    local_participant,
    reader_id,
    writer_id,
    sender.local_addr(),
    1L,
  ).unwrap()
  let message = @rtps.Message::new(
    @rtps.Header::new(remote_prefix, @rtps.VendorId::new(1, 15)),
  )
  message.add(
    @rtps.Submessage::new(
      @rtps.SubmessageId::Data,
      @rtps.DATA_FLAG_LITTLE_ENDIAN | @rtps.DATA_FLAG_INLINE_QOS,
      @rtps.DataSubmessage::new(reader_id, writer_id, 1L, b"").to_payload(),
    ),
  )
  message.add(
    remote_participant
    .to_data_submessage(reader_id, writer_id, 1L)
    .to_submessage(),
  )
  sender.send_message(message, session.socket.local_addr()).unwrap()
  let (event, _) = session.receive_once().unwrap()
  match event {
    DiscoveryEvent::Participant(decoded) =>
      assert_eq(decoded.to_cdr_bytes(), remote_participant.to_cdr_bytes())
    DiscoveryEvent::Publication(_) => fail("expected the SPDP participant")
    DiscoveryEvent::Subscription(_) => fail("expected the SPDP participant")
    DiscoveryEvent::EndpointRemoved(_, _) =>
      fail("expected the SPDP participant")
    DiscoveryEvent::ParticipantRemoved(_) =>
      fail("expected the SPDP participant")
  }
  session.close()
  sender.close()
}

///|
async test "discovery session ignores SPDP from another domain" {
  let local_prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let remote_prefix = @rtps.GuidPrefix::from_array([
    11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
  ]).unwrap()
  let participant_id = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
  ).unwrap()
  let reader_id = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
  ).unwrap()
  let writer_id = participant_id
  let local_participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(local_prefix, participant_id),
    @rtps.VendorId::new(1, 15),
    0U,
    60,
    0U,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR,
  )
  let other_domain = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(remote_prefix, participant_id),
    @rtps.VendorId::new(1, 15),
    1U,
    60,
    0U,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR,
  )
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let session = DiscoverySession::new(
    receiver,
    local_participant,
    reader_id,
    writer_id,
    @socket.Addr::new(0x7F000001U, 0),
    1L,
  ).unwrap()
  sender
  .send_spdp(
    other_domain,
    reader_id,
    writer_id,
    1L,
    session.socket.local_addr(),
  )
  .unwrap()
  sender
  .send_spdp(
    local_participant,
    reader_id,
    writer_id,
    2L,
    session.socket.local_addr(),
  )
  .unwrap()
  let (event, _) = session.receive_once().unwrap()
  match event {
    DiscoveryEvent::Participant(participant) =>
      assert_eq(participant.domain_id(), 0U)
    DiscoveryEvent::Publication(_) => fail("expected a participant event")
    DiscoveryEvent::Subscription(_) => fail("expected a participant event")
    DiscoveryEvent::EndpointRemoved(_, _) =>
      fail("expected a participant event")
    DiscoveryEvent::ParticipantRemoved(_) =>
      fail("expected a participant event")
  }
  sender.close()
  session.close()
}

///|
async test "discovery session receives from an additional metatraffic socket" {
  let prefix = match
    @rtps.GuidPrefix::from_array([11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]) {
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
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let primary = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let metatraffic = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let session = match
    DiscoverySession::new_with_receive_sockets(
      primary,
      [metatraffic],
      participant,
      reader_id,
      writer_id,
      sender.local_addr(),
      1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match
    sender.send_spdp(
      participant,
      reader_id,
      writer_id,
      1L,
      metatraffic.local_addr(),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (event, source) = match session.receive_once() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match event {
    DiscoveryEvent::Participant(decoded) =>
      assert_eq(decoded.to_cdr_bytes(), participant.to_cdr_bytes())
    DiscoveryEvent::Publication(_) => fail("expected an SPDP participant event")
    DiscoveryEvent::Subscription(_) =>
      fail("expected an SPDP participant event")
    DiscoveryEvent::EndpointRemoved(_, _) =>
      fail("expected an SPDP participant event")
    DiscoveryEvent::ParticipantRemoved(_) =>
      fail("expected an SPDP participant event")
  }
  assert_eq(source.ip(), 0x7F000001U)
  session.close()
  sender.close()
}

///|
async test "discovery session acknowledges reliable SEDP heartbeats" {
  let local_prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let remote_prefix = @rtps.GuidPrefix::from_array([
    11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
  ]).unwrap()
  let participant_id = @rtps.EntityId::new(
    b"prt",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
  ).unwrap()
  let spdp_reader = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
  ).unwrap()
  let spdp_writer = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
  ).unwrap()
  let sedp_writer = @rtps.EntityId::new(b"\x00\x00\x03", 0xC2).unwrap()
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let ack_receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(local_prefix, participant_id),
    @rtps.VendorId::new(1, 15),
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR |
    @rtps.BUILTIN_ENDPOINT_PUBLICATIONS_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PUBLICATIONS_DETECTOR,
  )
  let session = DiscoverySession::new(
    receiver,
    participant,
    spdp_reader,
    spdp_writer,
    sender.local_addr(),
    1L,
  ).unwrap()
  let remote_participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(remote_prefix, participant_id),
    @rtps.VendorId::new(1, 15),
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR |
    @rtps.BUILTIN_ENDPOINT_PUBLICATIONS_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PUBLICATIONS_DETECTOR,
  )
  remote_participant.add_metatraffic_unicast(
    ack_receiver.local_unicast_locator().unwrap(),
  )
  sender
  .send_data(
    remote_participant.to_data_submessage(spdp_reader, spdp_writer, 1L),
    remote_prefix,
    @rtps.VendorId::new(1, 15),
    session.socket.local_addr(),
  )
  .unwrap()
  let (participant_event, _) = session.receive_once().unwrap()
  match participant_event {
    DiscoveryEvent::Participant(discovered) =>
      assert_eq(discovered.participant_guid().prefix(), remote_prefix)
    _ => fail("expected an SPDP participant")
  }
  assert_true(sender.local_addr().port() != ack_receiver.local_addr().port())
  sender
  .send_heartbeat(
    @rtps.HeartbeatSubmessage::new(
      @rtps.EntityId::unknown(),
      sedp_writer,
      1L,
      1L,
      1U,
    ).unwrap(),
    remote_prefix,
    @rtps.VendorId::new(1, 15),
    session.socket.local_addr(),
  )
  .unwrap()
  let endpoint = @rtps.SedpEndpointData::new(
    @rtps.SedpEndpointKind::Publication,
    @rtps.Guid::new(remote_prefix, @rtps.EntityId::new(b"pub", 0xC2).unwrap()),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  sender
  .send_data(
    endpoint
    .to_data_submessage(@rtps.EntityId::unknown(), sedp_writer, 1L)
    .unwrap(),
    remote_prefix,
    @rtps.VendorId::new(1, 15),
    session.socket.local_addr(),
  )
  .unwrap()
  let (event, _) = session.receive_once().unwrap()
  match event {
    DiscoveryEvent::Publication(publication) =>
      assert_eq(publication.topic_name(), "rt/chatter")
    DiscoveryEvent::Participant(_) => fail("expected an SEDP publication")
    DiscoveryEvent::Subscription(_) => fail("expected an SEDP publication")
    DiscoveryEvent::EndpointRemoved(_, _) =>
      fail("expected an SEDP publication")
    DiscoveryEvent::ParticipantRemoved(_) =>
      fail("expected an SEDP publication")
  }
  let (acknack, _) = ack_receiver.receive_acknack().unwrap()
  assert_eq(
    acknack.reader_id(),
    @rtps.SedpEndpointKind::Publication.builtin_reader_id(),
  )
  assert_eq(acknack.writer_id(), sedp_writer)
  assert_eq(acknack.bitmap_base(), 1L)
  assert_eq(acknack.num_bits(), 1U)
  assert_eq(acknack.bitmap(), [0x80000000U])
  assert_true((acknack.flags() & @rtps.ACKNACK_FLAG_FINAL) == 0)
  sender
  .send_heartbeat(
    @rtps.HeartbeatSubmessage::new(
      @rtps.EntityId::unknown(),
      sedp_writer,
      1L,
      1L,
      2U,
    ).unwrap(),
    remote_prefix,
    @rtps.VendorId::new(1, 15),
    session.socket.local_addr(),
  )
  .unwrap()
  sender
  .send_data(
    endpoint
    .to_data_submessage(@rtps.EntityId::unknown(), sedp_writer, 2L)
    .unwrap(),
    remote_prefix,
    @rtps.VendorId::new(1, 15),
    session.socket.local_addr(),
  )
  .unwrap()
  let (complete_event, _) = session.receive_once().unwrap()
  match complete_event {
    DiscoveryEvent::Publication(_) => ()
    DiscoveryEvent::Participant(_) => fail("expected a repeated publication")
    DiscoveryEvent::Subscription(_) => fail("expected a repeated publication")
    DiscoveryEvent::EndpointRemoved(_, _) =>
      fail("expected a repeated publication")
    DiscoveryEvent::ParticipantRemoved(_) =>
      fail("expected a repeated publication")
  }
  let (complete_acknack, _) = ack_receiver.receive_acknack().unwrap()
  assert_eq(complete_acknack.bitmap_base(), 2L)
  assert_eq(complete_acknack.num_bits(), 0U)
  assert_eq(complete_acknack.bitmap(), [])
  assert_true((complete_acknack.flags() & @rtps.ACKNACK_FLAG_FINAL) != 0)
  sender
  .send_data(
    @rtps.DataSubmessage::new(@rtps.EntityId::unknown(), sedp_writer, 3L, b"")
    .with_key(endpoint.endpoint_guid().to_bytes())
    .with_status_info(@rtps.STATUS_INFO_DISPOSED),
    remote_prefix,
    @rtps.VendorId::new(1, 15),
    session.socket.local_addr(),
  )
  .unwrap()
  let (removed_event, _) = session.receive_once().unwrap()
  match removed_event {
    DiscoveryEvent::EndpointRemoved(kind, endpoint_guid) => {
      assert_eq(kind, @rtps.SedpEndpointKind::Publication)
      assert_eq(endpoint_guid, endpoint.endpoint_guid())
    }
    DiscoveryEvent::Participant(_) => fail("expected an SEDP removal event")
    DiscoveryEvent::Publication(_) => fail("expected an SEDP removal event")
    DiscoveryEvent::Subscription(_) => fail("expected an SEDP removal event")
    DiscoveryEvent::ParticipantRemoved(_) =>
      fail("expected an SEDP removal event")
  }
  session.close()
  sender.close()
  ack_receiver.close()
}

///|
async test "discovery session dispatches every SEDP endpoint in one RTPS message" {
  let local_prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let remote_prefix = @rtps.GuidPrefix::from_array([
    11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
  ]).unwrap()
  let vendor_id = @rtps.VendorId::new(1, 15)
  let participant_id = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
  ).unwrap()
  let spdp_reader = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
  ).unwrap()
  let participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(local_prefix, participant_id),
    vendor_id,
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR,
  )
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let session = DiscoverySession::new(
    receiver,
    participant,
    spdp_reader,
    participant_id,
    sender.local_addr(),
    1L,
  ).unwrap()
  let publication_writer = @rtps.SedpEndpointKind::Publication.builtin_writer_id()
  let first = @rtps.SedpEndpointData::new(
    @rtps.SedpEndpointKind::Publication,
    @rtps.Guid::new(
      remote_prefix,
      @rtps.EntityId::new(b"one", @rtps.ENTITYID_SEDP_PUBLICATIONS_WRITER).unwrap(),
    ),
    "rt/first",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  let second = @rtps.SedpEndpointData::new(
    @rtps.SedpEndpointKind::Publication,
    @rtps.Guid::new(
      remote_prefix,
      @rtps.EntityId::new(b"two", @rtps.ENTITYID_SEDP_PUBLICATIONS_WRITER).unwrap(),
    ),
    "rt/second",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  let third = @rtps.SedpEndpointData::new(
    @rtps.SedpEndpointKind::Publication,
    @rtps.Guid::new(
      remote_prefix,
      @rtps.EntityId::new(b"tri", @rtps.ENTITYID_SEDP_PUBLICATIONS_WRITER).unwrap(),
    ),
    "rt/third",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  let message = @rtps.Message::new(@rtps.Header::new(remote_prefix, vendor_id))
  message.add(
    first
    .to_data_submessage(@rtps.EntityId::unknown(), publication_writer, 1L)
    .unwrap()
    .to_submessage(),
  )
  message.add(
    second
    .to_data_submessage(@rtps.EntityId::unknown(), publication_writer, 2L)
    .unwrap()
    .to_submessage(),
  )
  sender.send_message(message, session.socket.local_addr()).unwrap()
  let (first_event, _) = session.receive_once().unwrap()
  match first_event {
    DiscoveryEvent::Publication(publication) =>
      assert_eq(publication.topic_name(), "rt/first")
    _ => fail("expected the first SEDP publication")
  }
  sender
  .send_data(
    third
    .to_data_submessage(@rtps.EntityId::unknown(), publication_writer, 3L)
    .unwrap(),
    remote_prefix,
    vendor_id,
    session.socket.local_addr(),
  )
  .unwrap()
  let (second_event, _) = session.receive_once().unwrap()
  match second_event {
    DiscoveryEvent::Publication(publication) =>
      assert_eq(publication.topic_name(), "rt/second")
    _ => fail("expected the second SEDP publication")
  }
  let (third_event, _) = session.receive_once().unwrap()
  match third_event {
    DiscoveryEvent::Publication(publication) =>
      assert_eq(publication.topic_name(), "rt/third")
    _ => fail("expected the third SEDP publication")
  }
  session.close()
  sender.close()
}

///|
async test "discovery session reassembles out-of-order SEDP DATA_FRAG" {
  let local_prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let remote_prefix = @rtps.GuidPrefix::from_array([
    11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
  ]).unwrap()
  let vendor_id = @rtps.VendorId::new(1, 15)
  let participant_id = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
  ).unwrap()
  let reader_id = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
  ).unwrap()
  let participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(local_prefix, participant_id),
    vendor_id,
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR,
  )
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let session = DiscoverySession::new(
    receiver,
    participant,
    reader_id,
    participant_id,
    sender.local_addr(),
    1L,
  ).unwrap()
  let publication_writer = @rtps.SedpEndpointKind::Publication.builtin_writer_id()
  let endpoint = @rtps.SedpEndpointData::new(
    @rtps.SedpEndpointKind::Publication,
    @rtps.Guid::new(
      remote_prefix,
      @rtps.EntityId::new(b"pub", @rtps.ENTITYID_SEDP_PUBLICATIONS_WRITER).unwrap(),
    ),
    "rt/fragmented",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  let payload = endpoint
    .to_data_submessage(@rtps.EntityId::unknown(), publication_writer, 1L)
    .unwrap()
    .serialized_payload()
  let fragment_size = (payload.length() + 1) / 2
  let final_payload : Array[Byte] = []
  for index in fragment_size..<payload.length() {
    final_payload.push(payload[index])
  }
  let first_payload : Array[Byte] = []
  for index in 0..<fragment_size {
    first_payload.push(payload[index])
  }
  let message = @rtps.Message::new(@rtps.Header::new(remote_prefix, vendor_id))
  message.add(
    @rtps.DataFragSubmessage::new(
      @rtps.EntityId::unknown(),
      publication_writer,
      1L,
      2U,
      1U.to_uint16(),
      fragment_size.to_uint16(),
      payload.length().reinterpret_as_uint(),
      Bytes::from_array(final_payload),
    )
    .unwrap()
    .to_submessage(),
  )
  message.add(
    @rtps.DataFragSubmessage::new(
      @rtps.EntityId::unknown(),
      publication_writer,
      1L,
      1U,
      1U.to_uint16(),
      fragment_size.to_uint16(),
      payload.length().reinterpret_as_uint(),
      Bytes::from_array(first_payload),
    )
    .unwrap()
    .to_submessage(),
  )
  let remote_participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(remote_prefix, participant_id),
    vendor_id,
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR,
  )
  message.add(
    remote_participant
    .to_data_submessage(reader_id, participant_id, 1L)
    .to_submessage(),
  )
  sender.send_message(message, session.socket.local_addr()).unwrap()
  let (publication_event, _) = session.receive_once().unwrap()
  match publication_event {
    DiscoveryEvent::Publication(publication) =>
      assert_eq(publication.topic_name(), "rt/fragmented")
    _ => fail("expected the reassembled SEDP publication")
  }
  let (participant_event, _) = session.receive_once().unwrap()
  match participant_event {
    DiscoveryEvent::Participant(discovered) =>
      assert_eq(discovered.participant_guid().prefix(), remote_prefix)
    _ => fail("expected the coalesced SPDP participant")
  }
  let dispose = endpoint.to_dispose_data_submessage(
    @rtps.EntityId::unknown(),
    publication_writer,
    2L,
  )
  let key_payload = dispose.serialized_payload()
  let first_key_payload : Array[Byte] = []
  let final_key_payload : Array[Byte] = []
  for index in 0..<8 {
    first_key_payload.push(key_payload[index])
    final_key_payload.push(key_payload[index + 8])
  }
  let final_key_fragment = @rtps.DataFragSubmessage::new(
    @rtps.EntityId::unknown(),
    publication_writer,
    2L,
    2U,
    1U.to_uint16(),
    8U.to_uint16(),
    16U,
    Bytes::from_array(final_key_payload),
  ).unwrap()
  let first_key_fragment = @rtps.DataFragSubmessage::new(
      @rtps.EntityId::unknown(),
      publication_writer,
      2L,
      1U,
      1U.to_uint16(),
      8U.to_uint16(),
      16U,
      Bytes::from_array(first_key_payload),
    )
    .unwrap()
    .with_inline_qos(dispose.inline_qos())
  let fragmented_dispose = @rtps.Message::new(
    @rtps.Header::new(remote_prefix, vendor_id),
  )
  fragmented_dispose.add(
    @rtps.Submessage::new(
      @rtps.SubmessageId::DataFrag,
      (final_key_fragment.flags() & 0xFB) | @rtps.DATA_FLAG_KEY,
      final_key_fragment.to_payload(),
    ),
  )
  fragmented_dispose.add(
    @rtps.Submessage::new(
      @rtps.SubmessageId::DataFrag,
      (first_key_fragment.flags() & 0xFB) | @rtps.DATA_FLAG_KEY,
      first_key_fragment.to_payload(),
    ),
  )
  sender.send_message(fragmented_dispose, session.socket.local_addr()).unwrap()
  match session.receive_once().unwrap().0 {
    DiscoveryEvent::EndpointRemoved(kind, endpoint_guid) => {
      assert_eq(kind, @rtps.SedpEndpointKind::Publication)
      assert_eq(endpoint_guid, endpoint.endpoint_guid())
    }
    _ => fail("expected the reassembled SEDP endpoint removal")
  }
  session.close()
  sender.close()
}

///|
async test "discovery session requests missing SEDP fragments" {
  let local_prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let remote_prefix = @rtps.GuidPrefix::from_array([
    11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
  ]).unwrap()
  let vendor_id = @rtps.VendorId::new(1, 15)
  let participant_id = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
  ).unwrap()
  let reader_id = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
  ).unwrap()
  let participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(local_prefix, participant_id),
    vendor_id,
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR,
  )
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let session = DiscoverySession::new(
    receiver,
    participant,
    reader_id,
    participant_id,
    sender.local_addr(),
    1L,
  ).unwrap()
  let publication_writer = @rtps.SedpEndpointKind::Publication.builtin_writer_id()
  let endpoint = @rtps.SedpEndpointData::new(
    @rtps.SedpEndpointKind::Publication,
    @rtps.Guid::new(
      remote_prefix,
      @rtps.EntityId::new(b"pub", @rtps.ENTITYID_SEDP_PUBLICATIONS_WRITER).unwrap(),
    ),
    "rt/fragmented",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  let payload = endpoint
    .to_data_submessage(@rtps.EntityId::unknown(), publication_writer, 1L)
    .unwrap()
    .serialized_payload()
  let fragment_size = (payload.length() + 1) / 2
  let first_payload : Array[Byte] = []
  for index in 0..<fragment_size {
    first_payload.push(payload[index])
  }
  let fragment = @rtps.DataFragSubmessage::new(
    @rtps.EntityId::unknown(),
    publication_writer,
    1L,
    1U,
    1U.to_uint16(),
    fragment_size.to_uint16(),
    payload.length().reinterpret_as_uint(),
    Bytes::from_array(first_payload),
  ).unwrap()
  let heartbeat = @rtps.HeartbeatFragSubmessage::new(
    @rtps.EntityId::unknown(),
    publication_writer,
    1L,
    2U,
    1U,
  ).unwrap()
  let remote_participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(remote_prefix, participant_id),
    vendor_id,
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR,
  )
  let message = @rtps.Message::new(@rtps.Header::new(remote_prefix, vendor_id))
  message.add(fragment.to_submessage())
  message.add(heartbeat.to_submessage())
  message.add(
    remote_participant
    .to_data_submessage(reader_id, participant_id, 1L)
    .to_submessage(),
  )
  sender.send_message(message, session.socket.local_addr()).unwrap()
  match session.receive_once().unwrap().0 {
    DiscoveryEvent::Participant(_) => ()
    _ => fail("expected the coalesced SPDP participant")
  }
  let (nackfrag, source) = sender.receive_nack_frag().unwrap()
  assert_eq(
    nackfrag.reader_id(),
    @rtps.SedpEndpointKind::Publication.builtin_reader_id(),
  )
  assert_eq(nackfrag.writer_id(), publication_writer)
  assert_eq(nackfrag.writer_sequence_number(), 1L)
  assert_eq(nackfrag.bitmap_base(), 1U)
  assert_eq(nackfrag.num_bits(), 2U)
  assert_eq(nackfrag.bitmap(), [0x40000000U])
  assert_eq(source.ip(), 0x7F000001U)
  session.close()
  sender.close()
}

///|
async test "discovery session reassembles fragmented SPDP participant data" {
  let local_prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let remote_prefix = @rtps.GuidPrefix::from_array([
    11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
  ]).unwrap()
  let vendor_id = @rtps.VendorId::new(1, 15)
  let participant_id = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
  ).unwrap()
  let reader_id = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
  ).unwrap()
  let local_participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(local_prefix, participant_id),
    vendor_id,
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR,
  )
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let session = DiscoverySession::new(
    receiver,
    local_participant,
    reader_id,
    participant_id,
    sender.local_addr(),
    1L,
  ).unwrap()
  let remote_participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(remote_prefix, participant_id),
    vendor_id,
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR,
  )
  let payload = remote_participant
    .to_data_submessage(reader_id, participant_id, 1L)
    .serialized_payload()
  let fragment_size = (payload.length() + 1) / 2
  let first_payload : Array[Byte] = []
  let final_payload : Array[Byte] = []
  for index in 0..<fragment_size {
    first_payload.push(payload[index])
  }
  for index in fragment_size..<payload.length() {
    final_payload.push(payload[index])
  }
  let message = @rtps.Message::new(@rtps.Header::new(remote_prefix, vendor_id))
  message.add(
    @rtps.DataFragSubmessage::new(
      reader_id,
      participant_id,
      1L,
      2U,
      1U.to_uint16(),
      fragment_size.to_uint16(),
      payload.length().reinterpret_as_uint(),
      Bytes::from_array(final_payload),
    )
    .unwrap()
    .to_submessage(),
  )
  message.add(
    @rtps.DataFragSubmessage::new(
      reader_id,
      participant_id,
      1L,
      1U,
      1U.to_uint16(),
      fragment_size.to_uint16(),
      payload.length().reinterpret_as_uint(),
      Bytes::from_array(first_payload),
    )
    .unwrap()
    .to_submessage(),
  )
  let marker = @rtps.SedpEndpointData::new(
    @rtps.SedpEndpointKind::Publication,
    @rtps.Guid::new(
      remote_prefix,
      @rtps.EntityId::new(b"pub", @rtps.ENTITYID_SEDP_PUBLICATIONS_WRITER).unwrap(),
    ),
    "rt/marker",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  message.add(
    marker
    .to_data_submessage(
      @rtps.EntityId::unknown(),
      @rtps.SedpEndpointKind::Publication.builtin_writer_id(),
      1L,
    )
    .unwrap()
    .to_submessage(),
  )
  sender.send_message(message, session.socket.local_addr()).unwrap()
  match session.receive_once().unwrap().0 {
    DiscoveryEvent::Participant(discovered) =>
      assert_eq(
        discovered.participant_guid(),
        remote_participant.participant_guid(),
      )
    _ => fail("expected the reassembled SPDP participant")
  }
  match session.receive_once().unwrap().0 {
    DiscoveryEvent::Publication(publication) =>
      assert_eq(publication.topic_name(), "rt/marker")
    _ => fail("expected the coalesced SEDP publication")
  }
  let dispose = remote_participant.to_dispose_data_submessage(
    reader_id, participant_id, 2L,
  )
  let key_payload = dispose.serialized_payload()
  let first_key_payload : Array[Byte] = []
  let final_key_payload : Array[Byte] = []
  for index in 0..<8 {
    first_key_payload.push(key_payload[index])
    final_key_payload.push(key_payload[index + 8])
  }
  let final_key_fragment = @rtps.DataFragSubmessage::new(
    reader_id,
    participant_id,
    2L,
    2U,
    1U.to_uint16(),
    8U.to_uint16(),
    key_payload.length().reinterpret_as_uint(),
    Bytes::from_array(final_key_payload),
  ).unwrap()
  let first_key_fragment = @rtps.DataFragSubmessage::new(
      reader_id,
      participant_id,
      2L,
      1U,
      1U.to_uint16(),
      8U.to_uint16(),
      key_payload.length().reinterpret_as_uint(),
      Bytes::from_array(first_key_payload),
    )
    .unwrap()
    .with_inline_qos(dispose.inline_qos())
  let fragmented_dispose = @rtps.Message::new(
    @rtps.Header::new(remote_prefix, vendor_id),
  )
  fragmented_dispose.add(
    @rtps.Submessage::new(
      @rtps.SubmessageId::DataFrag,
      (final_key_fragment.flags() & 0xFB) | @rtps.DATA_FLAG_KEY,
      final_key_fragment.to_payload(),
    ),
  )
  fragmented_dispose.add(
    @rtps.Submessage::new(
      @rtps.SubmessageId::DataFrag,
      (first_key_fragment.flags() & 0xFB) | @rtps.DATA_FLAG_KEY,
      first_key_fragment.to_payload(),
    ),
  )
  sender.send_message(fragmented_dispose, session.socket.local_addr()).unwrap()
  match session.receive_once().unwrap().0 {
    DiscoveryEvent::ParticipantRemoved(participant_guid) =>
      assert_eq(participant_guid, remote_participant.participant_guid())
    _ => fail("expected the reassembled SPDP participant removal")
  }
  session.close()
  sender.close()
}

///|
async test "discovery session filters SEDP data for another builtin reader" {
  let local_prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let remote_prefix = @rtps.GuidPrefix::from_array([
    11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
  ]).unwrap()
  let spdp_reader = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
  ).unwrap()
  let spdp_writer = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
  ).unwrap()
  let participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(local_prefix, spdp_writer),
    @rtps.VendorId::new(1, 15),
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER,
  )
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let session = DiscoverySession::new(
    receiver,
    participant,
    spdp_reader,
    spdp_writer,
    sender.local_addr(),
    1L,
  ).unwrap()
  let endpoint = @rtps.SedpEndpointData::new(
    @rtps.SedpEndpointKind::Publication,
    @rtps.Guid::new(remote_prefix, @rtps.EntityId::new(b"pub", 0xC2).unwrap()),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  let wrong_reader = @rtps.EntityId::new(b"bad", 0xC7).unwrap()
  sender
  .send_data(
    endpoint
    .to_data_submessage(
      wrong_reader,
      @rtps.SedpEndpointKind::Publication.builtin_writer_id(),
      1L,
    )
    .unwrap(),
    remote_prefix,
    @rtps.VendorId::new(1, 15),
    session.socket.local_addr(),
  )
  .unwrap()
  sender
  .send_data(
    endpoint
    .to_data_submessage(
      @rtps.SedpEndpointKind::Publication.builtin_reader_id(),
      @rtps.SedpEndpointKind::Publication.builtin_writer_id(),
      2L,
    )
    .unwrap(),
    remote_prefix,
    @rtps.VendorId::new(1, 15),
    session.socket.local_addr(),
  )
  .unwrap()
  let (event, _) = session.receive_once().unwrap()
  match event {
    DiscoveryEvent::Publication(publication) =>
      assert_eq(publication.endpoint_guid(), endpoint.endpoint_guid())
    DiscoveryEvent::Participant(_) => fail("expected an SEDP publication")
    DiscoveryEvent::Subscription(_) => fail("expected an SEDP publication")
    DiscoveryEvent::EndpointRemoved(_, _) =>
      fail("expected an SEDP publication")
    DiscoveryEvent::ParticipantRemoved(_) =>
      fail("expected an SEDP publication")
  }
  session.close()
  sender.close()
}
