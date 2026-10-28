///|
/// A datagram to deliver. The caller owns serialization, sockets, and errors.
pub(all) struct DiscoveryOutput {
  message : @core.Message
  destination : @core.Locator
}

///|
/// Discovery changes emitted independently of a transport.
pub(all) enum DiscoveryEvent {
  Participant(SpdpParticipantData)
  Publication(SedpEndpointData)
  Subscription(SedpEndpointData)
  EndpointRemoved(SedpEndpointKind, @core.Guid)
  ParticipantRemoved(@core.Guid)
}

///|
/// Effects from one input. Expirations precede received events.
pub(all) struct DiscoveryEffects {
  outgoing : Array[DiscoveryOutput]
  events : Array[DiscoveryEvent]
}

///|
struct DiscoveryRemoteDataReader {
  writer_prefix : @core.GuidPrefix
  writer_id : @core.EntityId
  endpoint_sequences : Array[DiscoveryEndpointSequence]
  reader : @core.ReliableDataReader
  expires_at : Int64?
}

///|
/// Sans-I/O discovery. Callers supply nondecreasing milliseconds and decoded
/// messages; no socket, clock, or async task is retained here.
pub struct DiscoveryEngine {
  participant : SpdpParticipantData
  reader_id : @core.EntityId
  writer_id : @core.EntityId
  sender : DiscoverySender
  spdp : SpdpState
  mut heartbeat_deadline : Int64?
  mut sedp_readers : Array[DiscoveryRemoteDataReader]
  mut spdp_fragment_readers : Array[DiscoveryRemoteDataReader]
}

///|
pub fn DiscoveryEngine::new(
  participant : SpdpParticipantData,
  reader_id : @core.EntityId,
  writer_id : @core.EntityId,
  destination : @core.Locator,
  first_sequence_number : Int64,
) -> Result[DiscoveryEngine, String] {
  let sender = match
    DiscoverySender::new(
      participant, reader_id, writer_id, destination, first_sequence_number,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({
    participant,
    reader_id,
    writer_id,
    sender,
    spdp: SpdpState::new(participant),
    heartbeat_deadline: None,
    sedp_readers: [],
    spdp_fragment_readers: [],
  })
}

///|
pub fn DiscoveryEngine::next_deadline(self : DiscoveryEngine) -> Int64? {
  let mut deadline = self.spdp.next_deadline()
  for remote in self.spdp_fragment_readers {
    if remote.expires_at is Some(expiry) {
      deadline = match deadline {
        Some(previous) =>
          Some(if expiry < previous { expiry } else { previous })
        None => Some(expiry)
      }
    }
  }
  match (deadline, self.heartbeat_deadline) {
    (Some(a), Some(b)) => Some(if a < b { a } else { b })
    (Some(a), None) => Some(a)
    (None, deadline) => deadline
  }
}

///|
pub fn DiscoveryEngine::advance(
  self : DiscoveryEngine,
  now_ms : Int64,
) -> DiscoveryEffects {
  self.spdp_fragment_readers = self.spdp_fragment_readers.filter(fn(remote) {
    match remote.expires_at {
      Some(deadline) => now_ms < deadline
      None => true
    }
  })
  let events = self.spdp
    .expire(now_ms)
    .map(fn(event) { self.map_participant_event(event) })
  let outgoing = match self.heartbeat_deadline {
    Some(deadline) if now_ms >= deadline => {
      self.heartbeat_deadline = Some(now_ms + 1000L)
      self.sender.heartbeats(self.spdp.participants())
    }
    _ => []
  }
  { outgoing, events, }
}

///|
pub fn DiscoveryEngine::next_sequence_number(self : DiscoveryEngine) -> Int64 {
  self.sender.next_sequence_number()
}

///|
pub fn DiscoveryEngine::announce_spdp(
  self : DiscoveryEngine,
  dispose : Bool,
) -> Result[Array[DiscoveryOutput], String] {
  self.sender.announce_spdp(dispose)
}

///|
pub fn DiscoveryEngine::next_sedp_sequence_number(
  self : DiscoveryEngine,
  kind : SedpEndpointKind,
) -> Int64 {
  self.sender.next_sedp_sequence_number(kind)
}

///|
pub fn DiscoveryEngine::announce_sedp(
  self : DiscoveryEngine,
  endpoint : SedpEndpointData,
  remotes : Array[SpdpParticipantData],
  dispose : Bool,
) -> Result[Array[DiscoveryOutput], String] {
  let result = self.sender.announce_sedp(endpoint, remotes, dispose)
  if result is Ok(_) && self.heartbeat_deadline is None {
    self.heartbeat_deadline = Some(0L)
  }
  result
}

///|
pub fn DiscoveryEngine::participants(
  self : DiscoveryEngine,
) -> Array[SpdpParticipantData] {
  self.spdp.participants()
}

///|
fn discovery_guid_prefix_is_unknown(prefix : @core.GuidPrefix) -> Bool {
  for byte in prefix.as_bytes() {
    if byte != 0 {
      return false
    }
  }
  true
}

///|
/// Replay existing builtin writer history to a newly discovered participant.
pub fn DiscoveryEngine::replay_sedp(
  self : DiscoveryEngine,
  remote : SpdpParticipantData,
) -> Result[Array[DiscoveryOutput], String] {
  self.sender.replay_sedp(remote)
}
