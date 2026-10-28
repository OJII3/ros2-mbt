///|
fn state_test_participant(
  id : Byte,
  seconds : Int32,
  nanos : UInt32,
) -> @discovery.SpdpParticipantData {
  let prefix = @core.GuidPrefix::from_array([
    id, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  @discovery.SpdpParticipantData::new(
    @core.Guid::new(prefix, @core.EntityId::new(b"abc", 0xC1).unwrap()),
    @core.VendorId::new(1, 15),
    0,
    seconds,
    nanos,
    3U,
  )
}

///|
fn state_test_announce(
  state : @discovery.SpdpState,
  participant : @discovery.SpdpParticipantData,
  now_ms : Int64,
) -> Array[@discovery.ParticipantEvent] {
  state.receive(
    participant.to_data_submessage(
      @core.EntityId::unknown(),
      @core.EntityId::unknown(),
      1L,
    ),
    now_ms,
  )
}

///|
test "SPDP deadlines include equality, refresh, and rediscovery" {
  let state = @discovery.SpdpState::new(state_test_participant(0, 60, 0U))
  let remote = state_test_participant(1, 1, 500_000_000U)
  assert_true(state_test_announce(state, remote, 100L)[0] is Participant(_))
  assert_eq(state.next_deadline(), Some(1600L))
  assert_eq(state.expire(1599L).length(), 0)
  assert_true(state_test_announce(state, remote, 1599L)[0] is Participant(_))
  assert_eq(state.next_deadline(), Some(3099L))
  assert_eq(state.expire(1600L).length(), 0)
  assert_eq(state.expire(3098L).length(), 0)
  let removed = state.expire(3099L)
  assert_eq(removed.length(), 1)
  assert_true(
    removed[0] is ParticipantRemoved(guid) && guid == remote.participant_guid(),
  )
  assert_eq(state.next_deadline(), None)
  assert_eq(state.expire(4000L).length(), 0)
  assert_eq(state_test_announce(state, remote, 5000L).length(), 1)
  assert_eq(state.next_deadline(), Some(6500L))
  assert_eq(state.expire(6501L).length(), 1)
}

///|
test "SPDP zero and fractional leases round up to milliseconds" {
  let state = @discovery.SpdpState::new(state_test_participant(0, 60, 0U))
  ignore(state_test_announce(state, state_test_participant(1, 0, 1U), 10L))
  assert_eq(state.next_deadline(), Some(11L))
  assert_eq(state.expire(10L).length(), 0)
  assert_eq(state.expire(11L).length(), 1)
  ignore(state_test_announce(state, state_test_participant(1, 0, 0U), 11L))
  assert_eq(state.expire(11L).length(), 1)
}

///|
test "SPDP finite and infinite leases can replace each other" {
  let state = @discovery.SpdpState::new(state_test_participant(0, 60, 0U))
  let finite = state_test_participant(1, 1, 0U)
  let infinite = state_test_participant(1, 0x7FFFFFFF, 0xFFFFFFFFU)
  ignore(state_test_announce(state, finite, 0L))
  ignore(state_test_announce(state, infinite, 1L))
  assert_eq(state.next_deadline(), None)
  assert_eq(state.expire(10_000_000_000L).length(), 0)
  ignore(state_test_announce(state, finite, 10_000_000_000L))
  assert_eq(state.expire(10_000_001_000L).length(), 1)
}

///|
test "SPDP dispose removes leases and allows rediscovery" {
  let state = @discovery.SpdpState::new(state_test_participant(0, 60, 0U))
  let remote = state_test_participant(1, 1, 0U)
  ignore(state_test_announce(state, remote, 0L))
  let dispose = remote.to_dispose_data_submessage(
    @core.EntityId::unknown(),
    @core.EntityId::unknown(),
    2L,
  )
  assert_true(
    state.receive(dispose, 100L)[0] is ParticipantRemoved(guid) &&
    guid == remote.participant_guid(),
  )
  assert_eq(state.next_deadline(), None)
  assert_eq(state.expire(1000L).length(), 0)
  assert_eq(state.receive(dispose, 1000L).length(), 1)
  ignore(state_test_announce(state, remote, 2000L))
  assert_eq(state.expire(3000L).length(), 1)
}

///|
test "SPDP selects earliest deadline and retains unrelated participants" {
  let local_participant = state_test_participant(0, 60, 0U)
  let state = @discovery.SpdpState::new(local_participant)
  ignore(state_test_announce(state, local_participant, 0L))
  assert_eq(state.next_deadline(), None)
  ignore(state_test_announce(state, state_test_participant(1, 3, 0U), 0L))
  ignore(state_test_announce(state, state_test_participant(2, 1, 0U), 0L))
  assert_eq(state.next_deadline(), Some(1000L))
  assert_eq(state.expire(1000L).length(), 1)
  assert_eq(state.next_deadline(), Some(3000L))
  assert_eq(state.participants().length(), 1)
  assert_eq(state.expire(3000L).length(), 1)
}

///|
test "SPDP long leases retain their absolute deadline" {
  let state = @discovery.SpdpState::new(state_test_participant(0, 60, 0U))
  ignore(
    state_test_announce(state, state_test_participant(1, 0x7FFFFFFF, 0U), 0L),
  )
  assert_eq(state.next_deadline(), Some(2147483647000L))
  assert_eq(state.expire(2147483647L).length(), 0)
  assert_eq(state.expire(2147483647000L).length(), 1)
}

///|
test "SPDP receive expires before same-deadline rediscovery under traffic" {
  let state = @discovery.SpdpState::new(state_test_participant(0, 60, 0U))
  let remote = state_test_participant(1, 1, 0U)
  ignore(state_test_announce(state, remote, 0L))
  for now in [1000L, 2000L, 4000L] {
    let events = state_test_announce(state, remote, now)
    assert_eq(events.length(), 2)
    assert_true(
      events[0] is ParticipantRemoved(guid) && guid == remote.participant_guid(),
    )
    assert_true(
      events[1] is Participant(participant) &&
      participant.participant_guid() == remote.participant_guid(),
    )
    assert_eq(state.next_deadline(), Some(now + 1000L))
    assert_eq(state.participants().length(), 1)
  }
}

///|
test "SPDP invalid receive still expires due participants" {
  let state = @discovery.SpdpState::new(state_test_participant(0, 60, 0U))
  let remote = state_test_participant(1, 1, 0U)
  ignore(state_test_announce(state, remote, 0L))
  let wrong_domain = @discovery.SpdpParticipantData::new(
    remote.participant_guid(),
    remote.vendor_id(),
    99,
    60,
    0U,
    3U,
  )
  let events = state_test_announce(state, wrong_domain, 1000L)
  assert_eq(events.length(), 1)
  assert_true(
    events[0] is ParticipantRemoved(guid) && guid == remote.participant_guid(),
  )
  assert_eq(state.next_deadline(), None)
}
