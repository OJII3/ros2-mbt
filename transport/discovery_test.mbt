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
  }
  match second {
    DiscoveryEvent::Participant(decoded) =>
      assert_eq(decoded.to_cdr_bytes(), participant.to_cdr_bytes())
    DiscoveryEvent::Publication(_) => fail("expected an SPDP participant event")
    DiscoveryEvent::Subscription(_) =>
      fail("expected an SPDP participant event")
  }
  assert_eq(source.ip(), 0x7F000001U)
  session.close()
  receiver.close()
}
