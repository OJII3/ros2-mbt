///|
/// Reliable receive state for one remote SEDP builtin writer.
struct DiscoverySedpReader {
  writer_prefix : @rtps.GuidPrefix
  writer_id : @rtps.EntityId
  reader : ReliableDataReader
}

///|
/// History for one local SEDP builtin writer.
struct DiscoverySedpWriter {
  kind : @rtps.SedpEndpointKind
  samples : Array[@rtps.DataSubmessage]
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
  sedp_writers : Array[DiscoverySedpWriter]
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
    sedp_writers: [],
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
    sedp_writers: [],
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
  self.announce_once_on(self.socket)
}

///| Send one SPDP announcement through a caller-provided socket.
async fn DiscoverySession::announce_once_on(
  self : DiscoverySession,
  socket : Udp,
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
/// Locate or create history for one local SEDP writer kind.
fn DiscoverySession::sedp_writer_index(
  self : DiscoverySession,
  kind : @rtps.SedpEndpointKind,
) -> Int {
  for index in 0..<self.sedp_writers.length() {
    if self.sedp_writers[index].kind == kind {
      return index
    }
  }
  self.sedp_writers.push({ kind, samples: [], })
  self.sedp_writers.length() - 1
}

///|
/// Retain one local SEDP sample for ACKNACK-driven retransmission.
fn DiscoverySession::remember_sedp_sample(
  self : DiscoverySession,
  endpoint : @rtps.SedpEndpointData,
  vendor_id : @rtps.VendorId,
  sequence_number : Int64,
) -> Result[Unit, String] {
  let kind = endpoint.kind()
  let sample = match
    endpoint.to_data_submessage_with_vendor(
      vendor_id,
      kind.builtin_reader_id(),
      kind.builtin_writer_id(),
      sequence_number,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let index = self.sedp_writer_index(kind)
  for sample_index in 0..<self.sedp_writers[index].samples.length() {
    if self.sedp_writers[index].samples[sample_index].writer_sequence_number() ==
      sequence_number {
      self.sedp_writers[index].samples[sample_index] = sample
      return Ok(())
    }
  }
  self.sedp_writers[index].samples.push(sample)
  Ok(())
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
/// Remember a received SEDP GAP for later ACKNACK generation.
fn DiscoverySession::record_sedp_gap(
  self : DiscoverySession,
  writer_prefix : @rtps.GuidPrefix,
  gap : @rtps.GapSubmessage,
) -> Unit {
  let index = match self.sedp_reader_index(writer_prefix, gap.writer_id()) {
    Ok(value) => value
    Err(_) => return
  }
  ignore(self.sedp_readers[index].reader.accept_gap(gap))
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
  let acknacks = match
    self.sedp_readers[index].reader.acknacks_for_heartbeat(heartbeat) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let socket = if socket_index == 0 {
    self.socket
  } else {
    self.receive_sockets[socket_index - 1]
  }
  for index in 0..<acknacks.length() {
    let acknack = if index + 1 == acknacks.length() {
      acknacks[index].with_final()
    } else {
      acknacks[index]
    }
    match
      socket.send_message(
        acknack.to_message(
          self.participant.participant_guid().prefix(),
          self.participant.vendor_id(),
        ).with_destination_guid_prefix(writer_prefix),
        source,
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(())
}

///|
fn discovery_acknack_bitmap_contains(
  bitmap : Array[UInt],
  offset : Int,
) -> Bool {
  let word_index = offset / 32
  let bit_index = offset % 32
  (bitmap[word_index] & (0x80000000U >> bit_index)) != 0U
}

///|
/// Retransmit local SEDP samples requested by one remote ACKNACK.
async fn DiscoverySession::retransmit_sedp_acknack(
  self : DiscoverySession,
  socket_index : Int,
  reader_prefix : @rtps.GuidPrefix,
  acknack : @rtps.AckNackSubmessage,
  source : @socket.Addr,
) -> Result[Unit, String] {
  let kind = match
    @rtps.SedpEndpointKind::from_builtin_writer_id(acknack.writer_id()) {
    Ok(value) => value
    Err(_) => return Ok(())
  }
  let writer_index = self.sedp_writer_index(kind)
  let socket = if socket_index == 0 {
    self.socket
  } else {
    self.receive_sockets[socket_index - 1]
  }
  let bitmap = acknack.bitmap()
  let num_bits = acknack.num_bits().reinterpret_as_int()
  for offset in 0..<num_bits {
    if !discovery_acknack_bitmap_contains(bitmap, offset) {
      continue
    }
    let sequence_number = acknack.bitmap_base() + offset.to_int64()
    for sample in self.sedp_writers[writer_index].samples {
      if sample.writer_sequence_number() != sequence_number {
        continue
      }
      match
        socket.send_message(
          sample.to_message(
            self.participant.participant_guid().prefix(),
            self.participant.vendor_id(),
          ).with_destination_guid_prefix(reader_prefix),
          source,
        ) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    }
  }
  Ok(())
}

///|
/// Decode one RTPS message into its first SPDP/SEDP discovery event.
async fn DiscoverySession::decode_message(
  self : DiscoverySession,
  message : @rtps.Message,
  source : @socket.Addr,
  socket_index : Int,
) -> Result[DiscoveryEvent?, String] {
  match message.destination_guid_prefix() {
    Ok(Some(destination)) if
      destination != self.participant.participant_guid().prefix() =>
      return Ok(None)
    Ok(_) => ()
    Err(message) => return Err(message)
  }
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
            let status = match data.status_info() {
              Ok(value) => value
              Err(_) => continue
            }
            match status {
              Some(value) if
                (value &
                  (@rtps.STATUS_INFO_DISPOSED |
                    @rtps.STATUS_INFO_UNREGISTERED)) != 0U => {
                if (data.flags() & @rtps.DATA_FLAG_KEY) == 0 {
                  continue
                }
                match
                  @rtps.SedpEndpointData::endpoint_guid_from_key_data(data) {
                  Ok(endpoint_guid) =>
                    if event is None {
                      event = Some(
                        DiscoveryEvent::EndpointRemoved(kind, endpoint_guid),
                      )
                    }
                  Err(_) => ()
                }
              }
              _ =>
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
          }
          Err(_) => {
            let status = match data.status_info() {
              Ok(value) => value
              Err(_) => continue
            }
            match status {
              Some(value) if
                (value &
                  (@rtps.STATUS_INFO_DISPOSED |
                    @rtps.STATUS_INFO_UNREGISTERED)) != 0U => {
                if (data.flags() & @rtps.DATA_FLAG_KEY) == 0 {
                  continue
                }
                match
                  @rtps.SpdpParticipantData::participant_guid_from_key_data(data) {
                  Ok(participant_guid) =>
                    if event is None {
                      event = Some(DiscoveryEvent::ParticipantRemoved(participant_guid))
                    }
                  Err(_) => ()
                }
              }
              _ =>
                if event is None {
                  match @rtps.SpdpParticipantData::from_data_submessage(data) {
                    Ok(participant) if
                      participant.domain_id() == self.participant.domain_id() =>
                      event = Some(DiscoveryEvent::Participant(participant))
                    Err(_) => ()
                    _ => ()
                  }
                }
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
      @rtps.SubmessageId::Gap => {
        let gap = match @rtps.GapSubmessage::from_submessage(submessage) {
          Ok(value) => value
          Err(_) => continue
        }
        if @rtps.SedpEndpointKind::from_builtin_writer_id(gap.writer_id())
          is Ok(_) {
          self.record_sedp_gap(message.header().guid_prefix(), gap)
        }
      }
      @rtps.SubmessageId::AckNack => {
        let acknack = match
          @rtps.AckNackSubmessage::from_submessage(submessage) {
          Ok(value) => value
          Err(_) => continue
        }
        match
          self.retransmit_sedp_acknack(
            socket_index,
            message.header().guid_prefix(),
            acknack,
            source,
          ) {
          Ok(_) => ()
          Err(message) => return Err(message)
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
