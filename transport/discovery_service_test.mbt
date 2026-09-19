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
