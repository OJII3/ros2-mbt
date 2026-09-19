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
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let receiver_address = receiver.local_addr()
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let session = match
    DiscoverySession::new(
      receiver, participant, reader_id, writer_id, receiver_address, 1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let service = DiscoveryService::new(session)
  match
    sender.send_spdp(participant, reader_id, writer_id, 1L, receiver_address) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (_, _) = match service.receive_once() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(service.graph().participant_count(), 1)
  service.close()
  sender.close()
}

///|
async test "discovery service announces SEDP endpoints to a participant" {
  let local_prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let remote_prefix = match
    @rtps.GuidPrefix::from_array([11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let participant_id = match
    @rtps.EntityId::new(b"abc", @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER) {
    Ok(value) => value
    Err(message) => fail(message)
  }
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
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let locator = match
    @rtps.Locator::udp_v4(
      b"\x7F\x00\x00\x01",
      receiver.local_addr().port().reinterpret_as_uint(),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  remote_participant.add_metatraffic_unicast(locator)
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
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
  let session = match
    DiscoverySession::new(
      sender,
      local_participant,
      reader_id,
      writer_id,
      receiver.local_addr(),
      1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let service = DiscoveryService::new(session)
  let endpoint_id = match @rtps.EntityId::new(b"def", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let endpoint = match
    @rtps.SedpEndpointData::new(
      @rtps.SedpEndpointKind::Publication,
      @rtps.Guid::new(local_prefix, endpoint_id),
      "rt/chatter",
      "std_msgs::msg::dds_::String_",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match service.announce_sedp_once(endpoint, remote_participant) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (decoded, source) = match
    receiver.receive_sedp(@rtps.SedpEndpointKind::Publication) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.topic_name(), "rt/chatter")
  assert_eq(decoded.type_name(), "std_msgs::msg::dds_::String_")
  assert_eq(source.ip(), 0x7F000001U)
  assert_eq(
    service.next_sedp_sequence_number(@rtps.SedpEndpointKind::Publication),
    2L,
  )
  assert_eq(
    service.next_sedp_sequence_number(@rtps.SedpEndpointKind::Subscription),
    1L,
  )
  service.close()
  receiver.close()
}

///|
async test "discovery service announces SEDP to all discovered participants" {
  let local_prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let remote_prefix = match
    @rtps.GuidPrefix::from_array([11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let participant_id = match
    @rtps.EntityId::new(b"abc", @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER) {
    Ok(value) => value
    Err(message) => fail(message)
  }
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
  let service_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let remote_receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let remote_locator = match
    @rtps.Locator::udp_v4(
      b"\x7F\x00\x00\x01",
      remote_receiver.local_addr().port().reinterpret_as_uint(),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  remote_participant.add_metatraffic_unicast(remote_locator)
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
  let session = match
    DiscoverySession::new(
      service_socket,
      local_participant,
      reader_id,
      writer_id,
      remote_receiver.local_addr(),
      1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let service = DiscoveryService::new(session)
  service.graph().ingest(DiscoveryEvent::Participant(remote_participant))
  let endpoint_id = match @rtps.EntityId::new(b"def", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let endpoint = match
    @rtps.SedpEndpointData::new(
      @rtps.SedpEndpointKind::Publication,
      @rtps.Guid::new(local_prefix, endpoint_id),
      "rt/chatter",
      "std_msgs::msg::dds_::String_",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match service.announce_sedp_to_all(endpoint) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (decoded, _) = match
    remote_receiver.receive_sedp(@rtps.SedpEndpointKind::Publication) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.topic_name(), "rt/chatter")
  assert_eq(
    service.next_sedp_sequence_number(@rtps.SedpEndpointKind::Publication),
    2L,
  )
  service.close()
  remote_receiver.close()
}
