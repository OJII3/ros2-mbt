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
