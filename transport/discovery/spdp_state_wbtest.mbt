///|
fn state_test_participant(
  id : Byte,
  seconds : Int32,
  nanos : UInt32,
) -> @rtps.SpdpParticipantData {
  let prefix = @rtps.GuidPrefix::from_array([
    id, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(prefix, @rtps.EntityId::new(b"abc", 0xC1).unwrap()),
    @rtps.VendorId::new(1, 15),
    0,
    seconds,
    nanos,
    3U,
  )
}

///|
fn state_test_announce(
  state : @participant_discovery.SpdpState,
  participant : @rtps.SpdpParticipantData,
  now_ms : Int64,
) -> Array[@participant_discovery.ParticipantEvent] {
  state.receive(
    participant.to_data_submessage(
      @rtps.EntityId::unknown(),
      @rtps.EntityId::unknown(),
      1L,
    ),
    now_ms,
  )
}

///|
async test "SPDP adapter clears only disappearing participant receive state" {
  let local_participant = state_test_participant(0, 60, 0U)
  let remote = state_test_participant(1, 0, 0U)
  let other = state_test_participant(2, 60, 0U)
  let socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  let session = DiscoverySession::new(
    socket,
    local_participant,
    @rtps.EntityId::unknown(),
    @rtps.EntityId::unknown(),
    socket.local_addr(),
    1L,
  ).unwrap()
  defer session.close()
  let writer = @rtps.SedpEndpointKind::Publication.builtin_writer_id()
  let prefix = remote.participant_guid().prefix()
  let other_prefix = other.participant_guid().prefix()
  ignore(session.sedp_reader_index(prefix, writer).unwrap())
  ignore(session.sedp_reader_index(other_prefix, writer).unwrap())
  ignore(session.spdp_fragment_reader_index(prefix))
  ignore(session.spdp_fragment_reader_index(other_prefix))
  ignore(state_test_announce(session.spdp, remote, session.clock.now_ms()))
  let (event, source) = @async.with_timeout(1000, async fn() {
    session.receive_once().unwrap()
  })
  assert_true(
    event is ParticipantRemoved(guid) && guid == remote.participant_guid(),
  )
  assert_eq(source, @socket.Addr::new(0, 0))
  assert_eq(session.sedp_readers.length(), 1)
  assert_eq(session.sedp_readers[0].writer_prefix, other_prefix)
  assert_eq(session.spdp_fragment_readers.length(), 1)
  assert_eq(session.spdp_fragment_readers[0].writer_prefix, other_prefix)
  // Rediscovery starts with fresh reliable/fragment receive state.
  ignore(state_test_announce(session.spdp, remote, session.clock.now_ms()))
  ignore(session.sedp_reader_index(prefix, writer).unwrap())
  ignore(session.spdp_fragment_reader_index(prefix))
  let events : Array[@wire.DiscoveryEvent] = []
  session.dispatch_spdp_data(
    events,
    remote.to_dispose_data_submessage(
      @rtps.EntityId::unknown(),
      @rtps.EntityId::unknown(),
      2L,
    ),
  )
  assert_true(events[0] is ParticipantRemoved(_))
  assert_eq(session.spdp.participants().length(), 0)
  assert_eq(session.sedp_readers.length(), 1)
  assert_eq(session.sedp_readers[0].writer_prefix, other_prefix)
  assert_eq(session.spdp_fragment_readers.length(), 1)
  assert_eq(session.spdp_fragment_readers[0].writer_prefix, other_prefix)
}

///|
async test "SPDP ready traffic yields expiry before rediscovery and clears SEDP" {
  let local_participant = state_test_participant(0, 60, 0U)
  let remote = state_test_participant(1, 60, 0U)
  let socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer sender.close()
  let session = DiscoverySession::new_default(socket, local_participant, 0U, 1L).unwrap()
  defer session.close()
  // An already due lease and a queued announcement make both paths ready.
  ignore(
    state_test_announce(
      session.spdp,
      state_test_participant(1, 0, 0U),
      session.clock.now_ms(),
    ),
  )
  let prefix = remote.participant_guid().prefix()
  ignore(
    session
    .sedp_reader_index(
      prefix,
      @rtps.SedpEndpointKind::Publication.builtin_writer_id(),
    )
    .unwrap(),
  )
  ignore(session.spdp_fragment_reader_index(prefix))
  ignore(
    sender
    .send_spdp(
      remote,
      session.reader_id,
      session.writer_id,
      1L,
      socket.local_addr(),
    )
    .unwrap(),
  )
  let (expired, expired_source) = @async.with_timeout(1000, async fn() {
    session.receive_once().unwrap()
  })
  assert_true(
    expired is ParticipantRemoved(guid) && guid == remote.participant_guid(),
  )
  assert_eq(expired_source, @socket.Addr::new(0, 0))
  assert_eq(session.sedp_readers.length(), 0)
  assert_eq(session.spdp_fragment_readers.length(), 0)
  let (discovered, source) = @async.with_timeout(1000, async fn() {
    session.receive_once().unwrap()
  })
  assert_true(
    discovered is Participant(participant) &&
    participant.participant_guid() == remote.participant_guid(),
  )
  assert_eq(source, sender.local_addr())
  assert_eq(session.spdp.participants().length(), 1)
}

///|
async test "SPDP expiry during dispatch has no packet source" {
  let local_participant = state_test_participant(0, 60, 0U)
  let remote = state_test_participant(1, 0, 0U)
  let socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  let session = DiscoverySession::new_default(socket, local_participant, 0U, 1L).unwrap()
  defer session.close()
  ignore(state_test_announce(session.spdp, remote, session.clock.now_ms()))
  let events : Array[@wire.DiscoveryEvent] = []
  session.dispatch_spdp_data(
    events,
    remote.to_data_submessage(session.reader_id, session.writer_id, 2L),
  )
  assert_eq(session.pending_events.length(), 1)
  assert_true(session.pending_events[0].0 is ParticipantRemoved(_))
  assert_eq(session.pending_events[0].1, @socket.Addr::new(0, 0))
  assert_true(events[0] is Participant(_))
}
