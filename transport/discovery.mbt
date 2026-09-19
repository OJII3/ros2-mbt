///|
/// Reliable receive state for one remote SEDP builtin writer.
struct DiscoverySedpReader {
  writer_prefix : @rtps.GuidPrefix
  writer_id : @rtps.EntityId
  reader : ReliableDataReader
}

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
  sedp_readers : Array[DiscoverySedpReader]
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
    sedp_readers: [],
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
    sedp_readers: [],
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
/// Return the receive result from one of the session's discovery sockets.
async fn DiscoverySession::receive_message(
  self : DiscoverySession,
) -> Result[(@rtps.Message, @socket.Addr, Int), String] {
  if self.receive_sockets.length() == 0 {
    let (message, source) = match self.socket.receive_message() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    return Ok((message, source, 0))
  }
  let tasks : Array[
    async () -> Result[(@rtps.Message, @socket.Addr, Int), String],
  ] = []
  tasks.push(async fn() {
    match self.socket.receive_message() {
      Ok((message, source)) => Ok((message, source, 0))
      Err(message) => Err(message)
    }
  })
  let mut receive_index = 1
  for receive_socket in self.receive_sockets {
    let index = receive_index
    tasks.push(async fn() {
      match receive_socket.receive_message() {
        Ok((message, source)) => Ok((message, source, index))
        Err(message) => Err(message)
      }
    })
    receive_index += 1
  }
  @async.any(tasks, allow_failure=true)
}

///|
/// Locate or create reliable receive state for one remote SEDP writer.
fn DiscoverySession::sedp_reader_index(
  self : DiscoverySession,
  writer_prefix : @rtps.GuidPrefix,
  writer_id : @rtps.EntityId,
) -> Result[Int, String] {
  for index in 0..<self.sedp_readers.length() {
    let reader = self.sedp_readers[index]
    if reader.writer_prefix == writer_prefix && reader.writer_id == writer_id {
      return Ok(index)
    }
  }
  let kind = match @rtps.SedpEndpointKind::from_builtin_writer_id(writer_id) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  self.sedp_readers.push({
    writer_prefix,
    writer_id,
    reader: ReliableDataReader::new(kind.builtin_reader_id(), writer_id),
  })
  Ok(self.sedp_readers.length() - 1)
}

///|
/// Remember a received SEDP DATA sample for later ACKNACK generation.
fn DiscoverySession::record_sedp_data(
  self : DiscoverySession,
  writer_prefix : @rtps.GuidPrefix,
  data : @rtps.DataSubmessage,
) -> Unit {
  let index = match self.sedp_reader_index(writer_prefix, data.writer_id()) {
    Ok(value) => value
    Err(_) => return
  }
  ignore(self.sedp_readers[index].reader.accept_data(data))
}

///|
/// Acknowledge a reliable SEDP HEARTBEAT on the socket that received it.
async fn DiscoverySession::acknowledge_sedp_heartbeat(
  self : DiscoverySession,
  socket_index : Int,
  writer_prefix : @rtps.GuidPrefix,
  heartbeat : @rtps.HeartbeatSubmessage,
  source : @socket.Addr,
) -> Result[Unit, String] {
  let index = match
    self.sedp_reader_index(writer_prefix, heartbeat.writer_id()) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let acknack = match
    self.sedp_readers[index].reader.acknack_for_heartbeat(heartbeat) {
    Ok(value) => value.with_final()
    Err(message) => return Err(message)
  }
  let socket = if socket_index == 0 {
    self.socket
  } else {
    self.receive_sockets[socket_index - 1]
  }
  socket.send_acknack(
    acknack,
    self.participant.participant_guid().prefix(),
    self.participant.vendor_id(),
    source,
  )
}

///|
/// Decode one RTPS message into its first SPDP/SEDP discovery event.
async fn DiscoverySession::decode_message(
  self : DiscoverySession,
  message : @rtps.Message,
  source : @socket.Addr,
  socket_index : Int,
) -> Result[DiscoveryEvent?, String] {
  let mut event : DiscoveryEvent? = None
  for submessage in message.submessages() {
    match submessage.id() {
      @rtps.SubmessageId::Data => {
        let data = match @rtps.DataSubmessage::from_submessage(submessage) {
          Ok(value) => value
          Err(_) => continue
        }
        match @rtps.SedpEndpointKind::from_builtin_writer_id(data.writer_id()) {
          Ok(kind) => {
            self.record_sedp_data(message.header().guid_prefix(), data)
            if event is None {
              match @rtps.SedpEndpointData::from_data_submessage(kind, data) {
                Ok(endpoint) =>
                  event = Some(
                    match kind {
                      @rtps.SedpEndpointKind::Publication =>
                        DiscoveryEvent::Publication(endpoint)
                      @rtps.SedpEndpointKind::Subscription =>
                        DiscoveryEvent::Subscription(endpoint)
                    },
                  )
                Err(_) => ()
              }
            }
          }
          Err(_) =>
            if event is None {
              match @rtps.SpdpParticipantData::from_data_submessage(data) {
                Ok(participant) =>
                  event = Some(DiscoveryEvent::Participant(participant))
                Err(_) => ()
              }
            }
        }
      }
      @rtps.SubmessageId::Heartbeat => {
        let heartbeat = match
          @rtps.HeartbeatSubmessage::from_submessage(submessage) {
          Ok(value) => value
          Err(_) => continue
        }
        if @rtps.SedpEndpointKind::from_builtin_writer_id(heartbeat.writer_id())
          is Ok(_) {
          match
            self.acknowledge_sedp_heartbeat(
              socket_index,
              message.header().guid_prefix(),
              heartbeat,
              source,
            ) {
            Ok(_) => ()
            Err(message) => return Err(message)
          }
        }
      }
      _ => ()
    }
  }
  Ok(event)
}

///|
/// Receive one discovery event and acknowledge reliable SEDP heartbeats.
pub async fn DiscoverySession::receive_once(
  self : DiscoverySession,
) -> Result[(DiscoveryEvent, @socket.Addr), String] {
  while true {
    let (message, source, socket_index) = match self.receive_message() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let event = match self.decode_message(message, source, socket_index) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    match event {
      Some(value) => return Ok((value, source))
      None => ()
    }
  } nobreak {
    Err("discovery receive loop stopped")
  }
}

///|
/// Close the session's underlying UDP socket.
pub fn DiscoverySession::close(self : DiscoverySession) -> Unit {
  self.socket.close()
  for receive_socket in self.receive_sockets {
    receive_socket.close()
  }
}
