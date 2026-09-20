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
    DiscoveryEvent::EndpointRemoved(_, _) => fail("expected an SPDP removal event")
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
    DiscoveryEvent::EndpointRemoved(_, _) => fail("expected the SPDP participant")
    DiscoveryEvent::ParticipantRemoved(_) => fail("expected the SPDP participant")
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
    DiscoveryEvent::EndpointRemoved(_, _) => fail("expected a participant event")
    DiscoveryEvent::ParticipantRemoved(_) => fail("expected a participant event")
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
    DiscoveryEvent::EndpointRemoved(_, _) => fail("expected an SEDP publication")
    DiscoveryEvent::ParticipantRemoved(_) => fail("expected an SEDP publication")
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
  assert_eq(complete_acknack.bitmap(), [0U])
  assert_true(
    (complete_acknack.flags() & @rtps.ACKNACK_FLAG_FINAL) != 0,
  )
  sender
  .send_data(
    @rtps.DataSubmessage::new(
      @rtps.EntityId::unknown(),
      sedp_writer,
      3L,
      b"",
    )
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
    DiscoveryEvent::ParticipantRemoved(_) => fail("expected an SEDP removal event")
  }
  session.close()
  sender.close()
  ack_receiver.close()
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
    @rtps.Guid::new(
      remote_prefix,
      @rtps.EntityId::new(b"pub", 0xC2).unwrap(),
    ),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  let wrong_reader = @rtps.EntityId::new(b"bad", 0xC7).unwrap()
  sender.send_data(
    endpoint.to_data_submessage(
      wrong_reader,
      @rtps.SedpEndpointKind::Publication.builtin_writer_id(),
      1L,
    ).unwrap(),
    remote_prefix,
    @rtps.VendorId::new(1, 15),
    session.socket.local_addr(),
  ).unwrap()
  sender.send_data(
    endpoint.to_data_submessage(
      @rtps.SedpEndpointKind::Publication.builtin_reader_id(),
      @rtps.SedpEndpointKind::Publication.builtin_writer_id(),
      2L,
    ).unwrap(),
    remote_prefix,
    @rtps.VendorId::new(1, 15),
    session.socket.local_addr(),
  ).unwrap()
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
