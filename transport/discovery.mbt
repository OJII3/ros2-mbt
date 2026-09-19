///|
/// State for periodically announcing one local participant through SPDP.
pub struct DiscoverySession {
  socket : Udp
  receive_sockets : Array[Udp]
  participant : @rtps.SpdpParticipantData
  reader_id : @rtps.EntityId
  writer_id : @rtps.EntityId
  destination : @socket.Addr
  mut next_sequence_number : Int64
}

///|
/// Create a discovery session with the first SPDP sequence number to send.
pub fn DiscoverySession::new(
  socket : Udp,
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
  })
}

///|
/// Create an SPDP session with additional metatraffic receive sockets.
///
/// DDSI-RTPS uses the domain multicast port for SPDP and a participant's
/// unicast metatraffic port for SEDP. The primary socket remains the send
/// socket; all sockets are raced when receiving discovery events.
pub fn DiscoverySession::new_with_receive_sockets(
  socket : Udp,
  receive_sockets : Array[Udp],
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
  })
}

///|
/// Create a default DDSI session with an additional metatraffic receiver.
pub fn DiscoverySession::new_default_with_receive_sockets(
  socket : Udp,
  receive_sockets : Array[Udp],
  participant : @rtps.SpdpParticipantData,
  domain_id : UInt,
  first_sequence_number : Int64,
) -> Result[DiscoverySession, String] {
  let destination = match ddsi_default_spdp_multicast_addr(domain_id) {
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
  socket : Udp,
  participant : @rtps.SpdpParticipantData,
  domain_id : UInt,
  first_sequence_number : Int64,
) -> Result[DiscoverySession, String] {
  let destination = match ddsi_default_spdp_multicast_addr(domain_id) {
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
/// Send one SPDP participant announcement and advance its sequence number.
pub async fn DiscoverySession::announce_once(
  self : DiscoverySession,
) -> Result[Unit, String] {
  let sequence_number = self.next_sequence_number
  match
    self.socket.send_spdp(
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
/// Receive one discovery event using this session's socket.
pub async fn DiscoverySession::receive_once(
  self : DiscoverySession,
) -> Result[(DiscoveryEvent, @socket.Addr), String] {
  if self.receive_sockets.length() == 0 {
    return self.socket.receive_discovery()
  }
  let tasks : Array[async () -> Result[(DiscoveryEvent, @socket.Addr), String]] = []
  tasks.push(async fn() { self.socket.receive_discovery() })
  for receive_socket in self.receive_sockets {
    tasks.push(async fn() { receive_socket.receive_discovery() })
  }
  @async.any(tasks, allow_failure=true)
}

///|
/// Close the session's underlying UDP socket.
pub fn DiscoverySession::close(self : DiscoverySession) -> Unit {
  self.socket.close()
  for receive_socket in self.receive_sockets {
    receive_socket.close()
  }
}
