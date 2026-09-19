///|
/// Coordinates a discovery session with an in-memory discovery graph.
pub struct DiscoveryService {
  session : DiscoverySession
  graph : DiscoveryGraph
  mut next_publication_sequence_number : Int64
  mut next_subscription_sequence_number : Int64
}

///|
pub fn DiscoveryService::new(session : DiscoverySession) -> DiscoveryService {
  {
    session,
    graph: DiscoveryGraph::new(),
    next_publication_sequence_number: 1L,
    next_subscription_sequence_number: 1L,
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
  match
    self.session.socket.send_sedp_to_participant(
      endpoint,
      self.session.participant.vendor_id(),
      remote_participant,
      sequence_number,
    ) {
    Ok(_) => {
      match endpoint.kind() {
        @rtps.SedpEndpointKind::Publication =>
          self.next_publication_sequence_number = sequence_number + 1L
        @rtps.SedpEndpointKind::Subscription =>
          self.next_subscription_sequence_number = sequence_number + 1L
      }
      Ok(())
    }
    Err(message) => Err(message)
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
  for remote_participant in self.graph.participants() {
    if remote_participant.participant_guid() == local_guid {
      continue
    }
    match self.announce_sedp_once(endpoint, remote_participant) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
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
  let (event, source) = match self.session.receive_once() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  self.graph.ingest(event)
  Ok((source, event))
}

///|
/// Receive one `ros_discovery_info` sample and upsert its participant graph.
pub async fn DiscoveryService::receive_ros_discovery_info(
  self : DiscoveryService,
) -> Result[(@socket.Addr, @ros.ParticipantEntitiesInfo), String] {
  let (info, source) = match self.session.socket.receive_ros_discovery_info() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  self.graph.ingest_ros_discovery_info(info)
  Ok((source, info))
}

///|
pub fn DiscoveryService::graph(self : DiscoveryService) -> DiscoveryGraph {
  self.graph
}

///|
pub fn DiscoveryService::close(self : DiscoveryService) -> Unit {
  self.session.close()
}
