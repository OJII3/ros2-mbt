///|
/// I/O-free SPDP state. Times are nondecreasing milliseconds in the caller's
/// clock; finite leases expire at (and after) their absolute deadline.
pub struct SpdpState {
  local_participant : SpdpParticipantData
  mut participants : Array[SpdpRemoteParticipant]
}

///|
struct SpdpRemoteParticipant {
  participant : SpdpParticipantData
  deadline : Int64?
}

///|
/// Create discovery state for a local participant.
pub fn SpdpState::new(local_participant : SpdpParticipantData) -> SpdpState {
  { local_participant, participants: [], }
}

///|
/// Return the earliest finite lease deadline in the caller's clock, if any.
pub fn SpdpState::next_deadline(self : SpdpState) -> Int64? {
  let mut earliest = None
  for remote in self.participants {
    if remote.deadline is Some(deadline) {
      match earliest {
        Some(previous) if previous <= deadline => ()
        _ => earliest = Some(deadline)
      }
    }
  }
  earliest
}

///|
fn SpdpState::remove(self : SpdpState, guid : @core.Guid) -> Unit {
  self.participants = self.participants.filter(fn(remote) {
    remote.participant.participant_guid() != guid
  })
}

///|
/// Remove participants whose deadlines are at or before `now_ms`.
pub fn SpdpState::expire(
  self : SpdpState,
  now_ms : Int64,
) -> Array[ParticipantEvent] {
  let events : Array[ParticipantEvent] = []
  let remaining : Array[SpdpRemoteParticipant] = []
  for remote in self.participants {
    match remote.deadline {
      Some(deadline) if deadline <= now_ms =>
        events.push(ParticipantRemoved(remote.participant.participant_guid()))
      _ => remaining.push(remote)
    }
  }
  self.participants = remaining
  events
}

///|
/// Parse announcements and key disposals. Repeated announcements refresh the
/// lease and still emit Participant, including local loopback announcements.
fn SpdpState::receive_sample(
  self : SpdpState,
  data : @core.DataSubmessage,
  now_ms : Int64,
) -> Array[ParticipantEvent] {
  let status = match data.status_info() {
    Ok(value) => value
    Err(_) => return []
  }
  match status {
    Some(value) if (
        value & (@core.STATUS_INFO_DISPOSED | @core.STATUS_INFO_UNREGISTERED)
      ) !=
      0U => {
      if (data.flags() & @core.DATA_FLAG_KEY) == 0 {
        return []
      }
      match SpdpParticipantData::participant_guid_from_key_data(data) {
        Ok(guid) => {
          self.remove(guid)
          [ParticipantRemoved(guid)]
        }
        Err(_) => []
      }
    }
    _ => {
      let participant = match
        SpdpParticipantData::from_data_submessage_with_default_domain(
          data,
          self.local_participant.domain_id(),
        ) {
        Ok(value) => value
        Err(_) => return []
      }
      if participant.domain_id() != self.local_participant.domain_id() {
        return []
      }
      if participant.participant_guid() !=
        self.local_participant.participant_guid() {
        let deadline = discovery_spdp_lease_milliseconds(participant).map(fn(
          duration,
        ) {
          now_ms + duration
        })
        let remote = SpdpRemoteParticipant::{ participant, deadline, }
        for index in 0..<self.participants.length() {
          if self.participants[index].participant.participant_guid() ==
            participant.participant_guid() {
            self.participants[index] = remote
            return [Participant(participant)]
          }
        }
        self.participants.push(remote)
      }
      [Participant(participant)]
    }
  }
}

///|
fn discovery_spdp_lease_milliseconds(
  participant : SpdpParticipantData,
) -> Int64? {
  let seconds = participant.lease_seconds()
  let nanoseconds = participant.lease_nanoseconds()
  if seconds == 0x7FFFFFFF && nanoseconds == 0xFFFFFFFFU {
    return None
  }
  if seconds < 0 || nanoseconds >= 1_000_000_000U {
    return None
  }
  let fractional_milliseconds = (nanoseconds.to_uint64() + 999_999U.to_uint64()) /
    1_000_000U.to_uint64()
  Some(
    seconds.to_int64() * 1000L + fractional_milliseconds.reinterpret_as_int64(),
  )
}

///|
/// Events produced by participant discovery without transport dependencies.
pub(all) enum ParticipantEvent {
  Participant(SpdpParticipantData)
  ParticipantRemoved(@core.Guid)
}

///|
/// Return a snapshot of remote participants for locator lookup.
pub fn SpdpState::participants(self : SpdpState) -> Array[SpdpParticipantData] {
  self.participants.map(fn(remote) { remote.participant })
}

///|
/// Process due expiries before the incoming sample, even when the sample is
/// malformed or refreshes a participant exactly at its deadline.
pub fn SpdpState::receive(
  self : SpdpState,
  data : @core.DataSubmessage,
  now_ms : Int64,
) -> Array[ParticipantEvent] {
  let events = self.expire(now_ms)
  for event in self.receive_sample(data, now_ms) {
    events.push(event)
  }
  events
}
