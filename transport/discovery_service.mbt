///|
/// Coordinates a discovery session with an in-memory discovery graph.
pub struct DiscoveryService {
  session : DiscoverySession
  graph : DiscoveryGraph
  mut next_publication_sequence_number : Int64
  mut next_subscription_sequence_number : Int64
  mut next_publication_heartbeat_count : UInt
  mut next_subscription_heartbeat_count : UInt
}

///|
pub fn DiscoveryService::new(session : DiscoverySession) -> DiscoveryService {
  {
    session,
    graph: DiscoveryGraph::new(),
    next_publication_sequence_number: 1L,
    next_subscription_sequence_number: 1L,
    next_publication_heartbeat_count: 1U,
    next_subscription_heartbeat_count: 1U,
  }
}

///|
/// Send one SPDP announcement through the underlying session.
pub async fn DiscoveryService::announce_once(
  self : DiscoveryService,
) -> Result[Unit, String] {
  self.session.announce_once()
}

///|
/// Advance the sequence and HEARTBEAT counters for one SEDP writer.
fn DiscoveryService::advance_sedp_counters(
  self : DiscoveryService,
  kind : @rtps.SedpEndpointKind,
) -> Unit {
  match kind {
    @rtps.SedpEndpointKind::Publication => {
      self.next_publication_sequence_number += 1L
      self.next_publication_heartbeat_count += 1U
    }
    @rtps.SedpEndpointKind::Subscription => {
      self.next_subscription_sequence_number += 1L
      self.next_subscription_heartbeat_count += 1U
    }
  }
}

///|
/// Send one SEDP sample to a participant using already selected counters.
async fn DiscoveryService::send_sedp_to_participant(
  self : DiscoveryService,
  endpoint : @rtps.SedpEndpointData,
  remote_participant : @rtps.SpdpParticipantData,
  sequence_number : Int64,
  heartbeat_count : UInt,
) -> Result[Unit, String] {
  match
    self.session.remember_sedp_sample(
      endpoint,
      self.session.participant.vendor_id(),
      sequence_number,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  self.session.socket.send_sedp_to_participant_with_heartbeat_count(
    endpoint,
    self.session.participant.vendor_id(),
    remote_participant,
    sequence_number,
    heartbeat_count,
  )
}

///|
/// Send one SEDP endpoint dispose sample to a participant.
async fn DiscoveryService::send_sedp_dispose_to_participant(
  self : DiscoveryService,
  endpoint : @rtps.SedpEndpointData,
  remote_participant : @rtps.SpdpParticipantData,
  sequence_number : Int64,
  heartbeat_count : UInt,
) -> Result[Unit, String] {
  match self.session.remember_sedp_dispose_sample(endpoint, sequence_number) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  self.session.socket.send_sedp_dispose_to_participant_with_heartbeat_count(
    endpoint,
    self.session.participant.vendor_id(),
    remote_participant,
    sequence_number,
    heartbeat_count,
  )
}

///|
/// Send one local SEDP endpoint announcement to a discovered participant.
pub async fn DiscoveryService::announce_sedp_once(
  self : DiscoveryService,
  endpoint : @rtps.SedpEndpointData,
  remote_participant : @rtps.SpdpParticipantData,
) -> Result[Unit, String] {
  let sequence_number = match endpoint.kind() {
    @rtps.SedpEndpointKind::Publication => self.next_publication_sequence_number
    @rtps.SedpEndpointKind::Subscription =>
      self.next_subscription_sequence_number
  }
  let heartbeat_count = match endpoint.kind() {
    @rtps.SedpEndpointKind::Publication => self.next_publication_heartbeat_count
    @rtps.SedpEndpointKind::Subscription =>
      self.next_subscription_heartbeat_count
  }
  match
    self.send_sedp_to_participant(
      endpoint, remote_participant, sequence_number, heartbeat_count,
    ) {
    Ok(_) => {
      self.advance_sedp_counters(endpoint.kind())
      Ok(())
    }
    Err(message) => {
      self.advance_sedp_counters(endpoint.kind())
      Err(message)
    }
  }
}

///|
/// Create a reliable SEDP writer on the discovery session's UDP socket.
///
/// The returned writer shares that socket with this service. While it is
/// receiving ACKNACKs, callers must not run another receive loop on the same
/// service socket.
pub fn DiscoveryService::new_reliable_sedp_writer(
  self : DiscoveryService,
  endpoint : @rtps.SedpEndpointData,
  remote_participant : @rtps.SpdpParticipantData,
  first_sequence_number : Int64,
) -> Result[ReliableSedpWriter, String] {
  ReliableSedpWriter::new(
    self.session.socket,
    self.session.participant.vendor_id(),
    endpoint,
    remote_participant,
    first_sequence_number,
  )
}

///|
/// Send one local SEDP endpoint announcement to every discovered participant.
pub async fn DiscoveryService::announce_sedp_to_all(
  self : DiscoveryService,
  endpoint : @rtps.SedpEndpointData,
) -> Result[Unit, String] {
  let local_guid = self.session.participant.participant_guid()
  let sequence_number = match endpoint.kind() {
    @rtps.SedpEndpointKind::Publication => self.next_publication_sequence_number
    @rtps.SedpEndpointKind::Subscription =>
      self.next_subscription_sequence_number
  }
  let heartbeat_count = match endpoint.kind() {
    @rtps.SedpEndpointKind::Publication => self.next_publication_heartbeat_count
    @rtps.SedpEndpointKind::Subscription =>
      self.next_subscription_heartbeat_count
  }
  let mut sent = false
  for remote_participant in self.graph.participants() {
    if remote_participant.participant_guid() == local_guid {
      continue
    }
    sent = true
    match
      self.send_sedp_to_participant(
        endpoint, remote_participant, sequence_number, heartbeat_count,
      ) {
      Ok(_) => ()
      Err(message) => {
        self.advance_sedp_counters(endpoint.kind())
        return Err(message)
      }
    }
  }
  if sent {
    self.advance_sedp_counters(endpoint.kind())
  }
  Ok(())
}

///|
/// Send a local SEDP endpoint dispose sample to every discovered participant.
pub async fn DiscoveryService::dispose_sedp_to_all(
  self : DiscoveryService,
  endpoint : @rtps.SedpEndpointData,
) -> Result[Unit, String] {
  let local_guid = self.session.participant.participant_guid()
  let sequence_number = match endpoint.kind() {
    @rtps.SedpEndpointKind::Publication => self.next_publication_sequence_number
    @rtps.SedpEndpointKind::Subscription =>
      self.next_subscription_sequence_number
  }
  let heartbeat_count = match endpoint.kind() {
    @rtps.SedpEndpointKind::Publication => self.next_publication_heartbeat_count
    @rtps.SedpEndpointKind::Subscription =>
      self.next_subscription_heartbeat_count
  }
  let mut sent = false
  for remote_participant in self.graph.participants() {
    if remote_participant.participant_guid() == local_guid {
      continue
    }
    sent = true
    match
      self.send_sedp_dispose_to_participant(
        endpoint, remote_participant, sequence_number, heartbeat_count,
      ) {
      Ok(_) => ()
      Err(message) => {
        self.advance_sedp_counters(endpoint.kind())
        return Err(message)
      }
    }
  }
  if sent {
    self.advance_sedp_counters(endpoint.kind())
  }
  Ok(())
}

///|
/// Send a local SEDP endpoint announcement a finite number of times.
pub async fn DiscoveryService::announce_sedp_n(
  self : DiscoveryService,
  endpoint : @rtps.SedpEndpointData,
  interval_ms : Int,
  count : Int,
) -> Result[Unit, String] {
  if interval_ms <= 0 {
    return Err("the SEDP announcement interval must be positive")
  }
  if count < 0 {
    return Err("the SEDP announcement count must not be negative")
  }
  for index in 0..<count {
    if index > 0 {
      @async.sleep(interval_ms)
    }
    match self.announce_sedp_to_all(endpoint) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(())
}

///|
/// Announce a local SEDP endpoint until the surrounding async task is stopped.
pub async fn DiscoveryService::announce_sedp_forever(
  self : DiscoveryService,
  endpoint : @rtps.SedpEndpointData,
  interval_ms : Int,
) -> Result[Unit, String] {
  if interval_ms <= 0 {
    return Err("the SEDP announcement interval must be positive")
  }
  while true {
    match self.announce_sedp_to_all(endpoint) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    @async.sleep(interval_ms)
  }
  Ok(())
}

///|
/// Return the next sequence number for a local SEDP endpoint kind.
pub fn DiscoveryService::next_sedp_sequence_number(
  self : DiscoveryService,
  kind : @rtps.SedpEndpointKind,
) -> Int64 {
  match kind {
    @rtps.SedpEndpointKind::Publication => self.next_publication_sequence_number
    @rtps.SedpEndpointKind::Subscription =>
      self.next_subscription_sequence_number
  }
}

///|
/// Receive one SPDP or SEDP event and upsert it into the graph.
pub async fn DiscoveryService::receive_once(
  self : DiscoveryService,
) -> Result[(@socket.Addr, DiscoveryEvent), String] {
  let (received_event, source) = match self.session.receive_once() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let event = match received_event {
    DiscoveryEvent::Publication(endpoint) =>
      DiscoveryEvent::Publication(
        self.endpoint_with_participant_locator(endpoint),
      )
    DiscoveryEvent::Subscription(endpoint) =>
      DiscoveryEvent::Subscription(
        self.endpoint_with_participant_locator(endpoint),
      )
    other => other
  }
  self.graph.ingest(event)
  Ok((source, event))
}

///|
/// Use the participant's default data locator when SEDP omits endpoint locators.
fn DiscoveryService::endpoint_with_participant_locator(
  self : DiscoveryService,
  endpoint : @rtps.SedpEndpointData,
) -> @rtps.SedpEndpointData {
  if endpoint.unicast_locators().length() > 0 ||
    endpoint.multicast_locators().length() > 0 {
    return endpoint
  }
  for participant in self.graph.participants() {
    if participant.participant_guid().prefix() !=
      endpoint.endpoint_guid().prefix() {
      continue
    }
    let unicast = participant.default_unicast_locators()
    if unicast.length() > 0 {
      endpoint.add_unicast_locator(unicast[0])
    } else {
      let multicast = participant.default_multicast_locators()
      if multicast.length() > 0 {
        endpoint.add_multicast_locator(multicast[0])
      }
    }
    break
  }
  endpoint
}

///|
/// Receive one `ros_discovery_info` sample and upsert its participant graph.
pub async fn DiscoveryService::receive_ros_discovery_info(
  self : DiscoveryService,
) -> Result[(@socket.Addr, @ros.ParticipantEntitiesInfo), String] {
  self.receive_ros_discovery_info_from(self.session.socket)
}

///|
/// Receive one graph sample from an explicitly supplied user-data socket.
///
/// This is the preferred form when SPDP/SEDP and user DATA use separate DDSI
/// sockets or ports.
pub async fn DiscoveryService::receive_ros_discovery_info_from(
  self : DiscoveryService,
  socket : Udp,
) -> Result[(@socket.Addr, @ros.ParticipantEntitiesInfo), String] {
  let (info, source) = match socket.receive_ros_discovery_info() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  self.ingest_ros_discovery_info(info)
  Ok((source, info))
}

///|
/// Receive one graph sample from a reliable discovered publication.
pub async fn DiscoveryService::receive_ros_discovery_info_reliable(
  self : DiscoveryService,
  reader : ReliableDataReaderSession,
) -> Result[(@socket.Addr, @ros.ParticipantEntitiesInfo), String] {
  let (data, source) = match reader.receive_data() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let info = match
    @ros.ParticipantEntitiesInfo::from_cdr_bytes(data.serialized_payload()) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  self.ingest_ros_discovery_info(info)
  Ok((source, info))
}

///|
/// Insert one decoded ROS graph sample into the discovery graph.
pub fn DiscoveryService::ingest_ros_discovery_info(
  self : DiscoveryService,
  info : @ros.ParticipantEntitiesInfo,
) -> Unit {
  self.graph.ingest_ros_discovery_info(info)
}

///|
pub fn DiscoveryService::graph(self : DiscoveryService) -> DiscoveryGraph {
  self.graph
}

///|
pub fn DiscoveryService::close(self : DiscoveryService) -> Unit {
  self.session.close()
}
