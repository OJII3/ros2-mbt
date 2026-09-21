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
  let receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
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
    @wire.DiscoveryEvent::Publication(decoded) => {
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
  let receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
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
    @wire.DiscoveryEvent::Participant(decoded) =>
      assert_eq(decoded.to_cdr_bytes(), participant.to_cdr_bytes())
    @wire.DiscoveryEvent::Publication(_) =>
      fail("expected an SPDP participant event")
    @wire.DiscoveryEvent::Subscription(_) =>
      fail("expected an SPDP participant event")
    @wire.DiscoveryEvent::EndpointRemoved(_, _) =>
      fail("expected an SPDP participant event")
    @wire.DiscoveryEvent::ParticipantRemoved(_) =>
      fail("expected an SPDP participant event")
  }
  match second {
    @wire.DiscoveryEvent::Participant(decoded) =>
      assert_eq(decoded.to_cdr_bytes(), participant.to_cdr_bytes())
    @wire.DiscoveryEvent::Publication(_) =>
      fail("expected an SPDP participant event")
    @wire.DiscoveryEvent::Subscription(_) =>
      fail("expected an SPDP participant event")
    @wire.DiscoveryEvent::EndpointRemoved(_, _) =>
      fail("expected an SPDP participant event")
    @wire.DiscoveryEvent::ParticipantRemoved(_) =>
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
    @wire.DiscoveryEvent::ParticipantRemoved(removed_guid) =>
      assert_eq(removed_guid, participant_guid)
    @wire.DiscoveryEvent::Participant(_) =>
      fail("expected an SPDP removal event")
    @wire.DiscoveryEvent::Publication(_) =>
      fail("expected an SPDP removal event")
    @wire.DiscoveryEvent::Subscription(_) =>
      fail("expected an SPDP removal event")
    @wire.DiscoveryEvent::EndpointRemoved(_, _) =>
      fail("expected an SPDP removal event")
  }
  match session.dispose_once() {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (outgoing_removed, _) = receiver.receive_discovery().unwrap()
  match outgoing_removed {
    @wire.DiscoveryEvent::ParticipantRemoved(removed_guid) =>
      assert_eq(removed_guid, participant_guid)
    @wire.DiscoveryEvent::Participant(_) =>
      fail("expected an outgoing SPDP removal")
    @wire.DiscoveryEvent::Publication(_) =>
      fail("expected an outgoing SPDP removal")
    @wire.DiscoveryEvent::Subscription(_) =>
      fail("expected an outgoing SPDP removal")
    @wire.DiscoveryEvent::EndpointRemoved(_, _) =>
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
  let receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
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
    @wire.DiscoveryEvent::Participant(decoded) =>
      assert_eq(decoded.to_cdr_bytes(), remote_participant.to_cdr_bytes())
    @wire.DiscoveryEvent::Publication(_) =>
      fail("expected the SPDP participant")
    @wire.DiscoveryEvent::Subscription(_) =>
      fail("expected the SPDP participant")
    @wire.DiscoveryEvent::EndpointRemoved(_, _) =>
      fail("expected the SPDP participant")
    @wire.DiscoveryEvent::ParticipantRemoved(_) =>
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
  let receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
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
    @wire.DiscoveryEvent::Participant(participant) =>
      assert_eq(participant.domain_id(), 0U)
    @wire.DiscoveryEvent::Publication(_) => fail("expected a participant event")
    @wire.DiscoveryEvent::Subscription(_) =>
      fail("expected a participant event")
    @wire.DiscoveryEvent::EndpointRemoved(_, _) =>
      fail("expected a participant event")
    @wire.DiscoveryEvent::ParticipantRemoved(_) =>
      fail("expected a participant event")
  }
  sender.close()
  session.close()
}

///|
async test "discovery session uses its domain when SPDP omits PID_DOMAIN_ID" {
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
    49U,
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
  let parameters = @rtps.ParameterList::new()
  for parameter in remote_participant.to_parameter_list().values() {
    if parameter.id() != @rtps.PID_DOMAIN_ID {
      parameters.add(parameter)
    }
  }
  let cdr_payload = parameters.to_cdr_bytes()
  let data = @rtps.DataSubmessage::new(
    reader_id,
    writer_id,
    1L,
    cdr_payload[4:].to_owned(),
  )
  let message = @rtps.Message::new(
    @rtps.Header::new(remote_prefix, @rtps.VendorId::new(1, 15)),
  )
  message.add(data.to_submessage())
  let receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let session = DiscoverySession::new(
    receiver,
    local_participant,
    reader_id,
    writer_id,
    sender.local_addr(),
    1L,
  ).unwrap()
  sender.send_message(message, session.socket.local_addr()).unwrap()
  let (event, _) = session.receive_once().unwrap()
  match event {
    @wire.DiscoveryEvent::Participant(participant) =>
      assert_eq(participant.domain_id(), 49U)
    @wire.DiscoveryEvent::Publication(_) => fail("expected an SPDP participant")
    @wire.DiscoveryEvent::Subscription(_) =>
      fail("expected an SPDP participant")
    @wire.DiscoveryEvent::EndpointRemoved(_, _) =>
      fail("expected an SPDP participant")
    @wire.DiscoveryEvent::ParticipantRemoved(_) =>
      fail("expected an SPDP participant")
  }
  session.close()
  sender.close()
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
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let primary = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let metatraffic = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
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
    @wire.DiscoveryEvent::Participant(decoded) =>
      assert_eq(decoded.to_cdr_bytes(), participant.to_cdr_bytes())
    @wire.DiscoveryEvent::Publication(_) =>
      fail("expected an SPDP participant event")
    @wire.DiscoveryEvent::Subscription(_) =>
      fail("expected an SPDP participant event")
    @wire.DiscoveryEvent::EndpointRemoved(_, _) =>
      fail("expected an SPDP participant event")
    @wire.DiscoveryEvent::ParticipantRemoved(_) =>
      fail("expected an SPDP participant event")
  }
  assert_eq(source.ip(), 0x7F000001U)
  session.close()
  sender.close()
}

///|
