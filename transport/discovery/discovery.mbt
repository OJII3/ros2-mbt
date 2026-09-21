///|
/// Reliable receive state for one remote discovery builtin writer.
struct DiscoveryRemoteDataReader {
  writer_prefix : @rtps.GuidPrefix
  writer_id : @rtps.EntityId
  reader : @wire.ReliableDataReader
}

///|
/// History for one local SEDP builtin writer.
struct DiscoverySedpWriter {
  kind : @rtps.SedpEndpointKind
  samples : Array[@rtps.DataSubmessage]
}

///|
struct DiscoveryRemoteParticipant {
  mut participant : @rtps.SpdpParticipantData
  mut lease_timer : @async.Timer?
  mut lease_remaining_ms : Int64
  mut lease_segment_ms : Int
}

///|
priv enum DiscoveryReceiveOutcome {
  Message(@rtps.Message, @socket.Addr, Int)
  ParticipantLeaseExpired(@rtps.Guid)
}

///|
const DISCOVERY_MAX_TIMER_MILLISECONDS : Int = 0x7FFFFFFF

///|
/// Return whether an RTPS destination prefix addresses every participant.
fn transport_guid_prefix_is_unknown(prefix : @rtps.GuidPrefix) -> Bool {
  for byte in prefix.as_bytes() {
    if byte != 0 {
      return false
    }
  }
  true
}

///|
/// State for periodically announcing one local participant through SPDP.
pub struct DiscoverySession {
  socket : @wire.Udp
  receive_sockets : Array[@wire.Udp]
  participant : @rtps.SpdpParticipantData
  reader_id : @rtps.EntityId
  writer_id : @rtps.EntityId
  destination : @socket.Addr
  mut next_sequence_number : Int64
  mut sedp_readers : Array[DiscoveryRemoteDataReader]
  mut spdp_fragment_readers : Array[DiscoveryRemoteDataReader]
  sedp_writers : Array[DiscoverySedpWriter]
  mut remote_participants : Array[DiscoveryRemoteParticipant]
  mut pending_events : Array[(@wire.DiscoveryEvent, @socket.Addr)]
  mut pending_event_index : Int
}

///|
/// Create a discovery session with the first SPDP sequence number to send.
pub fn DiscoverySession::new(
  socket : @wire.Udp,
  participant : @rtps.SpdpParticipantData,
  reader_id : @rtps.EntityId,
  writer_id : @rtps.EntityId,
  destination : @socket.Addr,
  first_sequence_number : Int64,
) -> Result[DiscoverySession, String] {
  if first_sequence_number < 1L {
    return Err("an SPDP sequence number must be positive")
  }
  Ok({
    socket,
    receive_sockets: [],
    participant,
    reader_id,
    writer_id,
    destination,
    next_sequence_number: first_sequence_number,
    sedp_readers: [],
    spdp_fragment_readers: [],
    sedp_writers: [],
    remote_participants: [],
    pending_events: [],
    pending_event_index: 0,
  })
}

///|
/// Create an SPDP session with additional metatraffic receive sockets.
///
/// DDSI-RTPS uses the domain multicast port for SPDP and a participant's
/// unicast metatraffic port for SEDP. The primary socket remains the send
/// socket; all sockets are raced when receiving discovery events.
pub fn DiscoverySession::new_with_receive_sockets(
  socket : @wire.Udp,
  receive_sockets : Array[@wire.Udp],
  participant : @rtps.SpdpParticipantData,
  reader_id : @rtps.EntityId,
  writer_id : @rtps.EntityId,
  destination : @socket.Addr,
  first_sequence_number : Int64,
) -> Result[DiscoverySession, String] {
  if first_sequence_number < 1L {
    return Err("an SPDP sequence number must be positive")
  }
  Ok({
    socket,
    receive_sockets,
    participant,
    reader_id,
    writer_id,
    destination,
    next_sequence_number: first_sequence_number,
    sedp_readers: [],
    spdp_fragment_readers: [],
    sedp_writers: [],
    remote_participants: [],
    pending_events: [],
    pending_event_index: 0,
  })
}

///|
/// Create a default DDSI session with an additional metatraffic receiver.
pub fn DiscoverySession::new_default_with_receive_sockets(
  socket : @wire.Udp,
  receive_sockets : Array[@wire.Udp],
  participant : @rtps.SpdpParticipantData,
  domain_id : UInt,
  first_sequence_number : Int64,
) -> Result[DiscoverySession, String] {
  let destination = match @wire.ddsi_default_spdp_multicast_addr(domain_id) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let reader_id = match
    @rtps.EntityId::new(
      b"\x00\x01\x00",
      @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let writer_id = match
    @rtps.EntityId::new(
      b"\x00\x01\x00",
      @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  DiscoverySession::new_with_receive_sockets(
    socket, receive_sockets, participant, reader_id, writer_id, destination, first_sequence_number,
  )
}

///|
/// Create an SPDP session using the DDSI-RTPS default multicast destination.
pub fn DiscoverySession::new_default(
  socket : @wire.Udp,
  participant : @rtps.SpdpParticipantData,
  domain_id : UInt,
  first_sequence_number : Int64,
) -> Result[DiscoverySession, String] {
  let destination = match @wire.ddsi_default_spdp_multicast_addr(domain_id) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let reader_id = match
    @rtps.EntityId::new(
      b"\x00\x01\x00",
      @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let writer_id = match
    @rtps.EntityId::new(
      b"\x00\x01\x00",
      @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  DiscoverySession::new(
    socket, participant, reader_id, writer_id, destination, first_sequence_number,
  )
}

///|
/// Return the sequence number that will be used by the next announcement.
pub fn DiscoverySession::next_sequence_number(self : DiscoverySession) -> Int64 {
  self.next_sequence_number
}

///|
/// Return the local participant announced by this session.
pub fn DiscoverySession::participant(
  self : DiscoverySession,
) -> @rtps.SpdpParticipantData {
  self.participant
}

///|
/// Send one SPDP participant announcement and advance its sequence number.
pub async fn DiscoverySession::announce_once(
  self : DiscoverySession,
) -> Result[Unit, String] {
  self.announce_once_on(self.socket)
}

///|
/// Send the local participant dispose through a caller-provided socket.
async fn DiscoverySession::dispose_once_on(
  self : DiscoverySession,
  socket : @wire.Udp,
) -> Result[Unit, String] {
  let sequence_number = self.next_sequence_number
  let data = self.participant.to_dispose_data_submessage(
    self.reader_id,
    self.writer_id,
    sequence_number,
  )
  match
    socket.send_message(
      data.to_message(
        self.participant.participant_guid().prefix(),
        self.participant.vendor_id(),
      ),
      self.destination,
    ) {
    Ok(_) => {
      self.next_sequence_number = sequence_number + 1L
      Ok(())
    }
    Err(message) => Err(message)
  }
}

///|
/// Send a key-only SPDP dispose sample for the local participant.
pub async fn DiscoverySession::dispose_once(
  self : DiscoverySession,
) -> Result[Unit, String] {
  self.dispose_once_on(self.socket)
}

///|
/// Send one SPDP announcement through a caller-provided socket.
async fn DiscoverySession::announce_once_on(
  self : DiscoverySession,
  socket : @wire.Udp,
) -> Result[Unit, String] {
  let sequence_number = self.next_sequence_number
  match
    socket.send_spdp(
      self.participant,
      self.reader_id,
      self.writer_id,
      sequence_number,
      self.destination,
    ) {
    Ok(_) => {
      self.next_sequence_number = sequence_number + 1L
      Ok(())
    }
    Err(message) => Err(message)
  }
}

///|
/// Send a finite sequence of SPDP announcements at the given interval.
pub async fn DiscoverySession::announce_n(
  self : DiscoverySession,
  interval_ms : Int,
  count : Int,
) -> Result[Unit, String] {
  if interval_ms <= 0 {
    return Err("the discovery announcement interval must be positive")
  }
  if count < 0 {
    return Err("the discovery announcement count must not be negative")
  }
  for index in 0..<count {
    if index > 0 {
      @async.sleep(interval_ms)
    }
    match self.announce_once() {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(())
}

///|
/// Announce the local participant until the surrounding async task is stopped.
///
/// Cancellation is intentionally left to the caller's task group so the same
/// session can be used in a receive loop owned by the application.
pub async fn DiscoverySession::announce_forever(
  self : DiscoverySession,
  interval_ms : Int,
) -> Result[Unit, String] {
  if interval_ms <= 0 {
    return Err("the discovery announcement interval must be positive")
  }
  while true {
    match self.announce_once() {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    @async.sleep(interval_ms)
  }
  Ok(())
}

///|
/// Receive one discovery event and acknowledge reliable SEDP heartbeats.
/// A participant-lease expiry has no packet source and uses `0.0.0.0:0`.
pub async fn DiscoverySession::receive_once(
  self : DiscoverySession,
) -> Result[(@wire.DiscoveryEvent, @socket.Addr), String] {
  while true {
    if self.pending_event_index < self.pending_events.length() {
      let event = self.pending_events[self.pending_event_index]
      self.pending_event_index += 1
      if self.pending_event_index == self.pending_events.length() {
        self.pending_events = []
        self.pending_event_index = 0
      }
      return Ok(event)
    }
    match self.receive_message_or_lease_expiry() {
      Ok(DiscoveryReceiveOutcome::Message(message, source, socket_index)) => {
        let events = match self.decode_message(message, source, socket_index) {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        for event in events {
          self.pending_events.push((event, source))
        }
      }
      Ok(DiscoveryReceiveOutcome::ParticipantLeaseExpired(participant_guid)) =>
        if self.advance_expired_participant_lease(participant_guid) {
          self.forget_remote_participant(participant_guid)
          return Ok(
            (
              @wire.DiscoveryEvent::ParticipantRemoved(participant_guid),
              @socket.Addr::new(0, 0),
            ),
          )
        }
      Err(message) => return Err(message)
    }
  } nobreak {
    Err("discovery receive loop stopped")
  }
}

///|
/// Close the session's underlying UDP socket.
pub fn DiscoverySession::close(self : DiscoverySession) -> Unit {
  for remote in self.remote_participants {
    match remote.lease_timer {
      Some(timer) => timer.cancel()
      None => ()
    }
  }
  self.socket.close()
  for receive_socket in self.receive_sockets {
    receive_socket.close()
  }
}
