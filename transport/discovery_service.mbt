///|
/// Coordinates a discovery session with an in-memory discovery graph.
pub struct DiscoveryService {
  session : DiscoverySession
  graph : DiscoveryGraph
}

///|
pub fn DiscoveryService::new(session : DiscoverySession) -> DiscoveryService {
  { session, graph: DiscoveryGraph::new(), }
}

///|
/// Send one SPDP announcement through the underlying session.
pub async fn DiscoveryService::announce_once(
  self : DiscoveryService,
) -> Result[Unit, String] {
  self.session.announce_once()
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
pub fn DiscoveryService::graph(self : DiscoveryService) -> DiscoveryGraph {
  self.graph
}

///|
pub fn DiscoveryService::close(self : DiscoveryService) -> Unit {
  self.session.close()
}
