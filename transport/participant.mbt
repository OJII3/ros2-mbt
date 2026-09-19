///|
/// A native UDP ROS 2 participant with discovery and user-data sockets.
///
/// This type owns the socket lifecycle, while endpoint matching and message
/// serialization remain explicit in the existing topic facades.
pub struct RosParticipant {
  participant : @rtps.SpdpParticipantData
  discovery : DiscoveryService
  user_socket : Udp
  user_locator : @rtps.Locator
  local_endpoints : Array[@rtps.SedpEndpointData]
}

///|
/// Build a participant from already-bound sockets.
///
/// This constructor is useful when an application needs custom socket
/// binding. The discovery session still announces to the DDSI multicast
/// address for `domain_id`.
pub fn RosParticipant::from_sockets(
  discovery_socket : Udp,
  user_socket : Udp,
  participant : @rtps.SpdpParticipantData,
  domain_id : UInt,
  first_sequence_number : Int64,
) -> Result[RosParticipant, String] {
  let session = match
    DiscoverySession::new_default(
      discovery_socket, participant, domain_id, first_sequence_number,
    ) {
    Ok(value) => value
    Err(message) => {
      user_socket.close()
      return Err(message)
    }
  }
  RosParticipant::from_discovery_session(session, user_socket)
}

///|
/// Build a participant from a caller-configured discovery session.
///
/// This is useful for custom discovery destinations and deterministic unicast
/// tests. The session's participant data is used as the local identity.
pub fn RosParticipant::from_discovery_session(
  session : DiscoverySession,
  user_socket : Udp,
) -> Result[RosParticipant, String] {
  let user_locator = match user_socket.local_unicast_locator() {
    Ok(value) => value
    Err(message) => {
      session.close()
      user_socket.close()
      return Err(message)
    }
  }
  let participant = session.participant
  Ok({
    participant,
    discovery: DiscoveryService::new(session),
    user_socket,
    user_locator,
    local_endpoints: [],
  })
}

///|
/// Build a participant using the standard DDSI-RTPS IPv4 ports.
pub async fn RosParticipant::new_ddsi(
  guid_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  domain_id : UInt,
  participant_id : UInt,
  ip : UInt,
  lease_seconds : Int,
  first_sequence_number : Int64,
) -> Result[RosParticipant, String] {
  let participant = match
    new_ddsi_participant(
      guid_prefix, vendor_id, domain_id, participant_id, ip, lease_seconds,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let discovery_socket = match Udp::ddsi_spdp_multicast(domain_id) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let user_socket = match
    Udp::ddsi_user_unicast(domain_id, participant_id, ip) {
    Ok(value) => value
    Err(message) => {
      discovery_socket.close()
      return Err(message)
    }
  }
  RosParticipant::from_sockets(
    discovery_socket, user_socket, participant, domain_id, first_sequence_number,
  )
}

///|
/// Return the local SPDP participant data.
pub fn RosParticipant::participant(
  self : RosParticipant,
) -> @rtps.SpdpParticipantData {
  self.participant
}

///|
/// Return the locator advertised for the bound user-data socket.
pub fn RosParticipant::user_locator(self : RosParticipant) -> @rtps.Locator {
  self.user_locator
}

///|
/// Return the current discovery graph.
pub fn RosParticipant::graph(self : RosParticipant) -> DiscoveryGraph {
  self.discovery.graph()
}

///|
/// Return the local SEDP endpoints registered with this participant.
pub fn RosParticipant::local_endpoints(
  self : RosParticipant,
) -> Array[@rtps.SedpEndpointData] {
  self.local_endpoints
}

///|
/// Build one ROS graph-discovery sample from the registered local endpoints.
pub fn RosParticipant::participant_entities_info(
  self : RosParticipant,
  node_namespace : String,
  node_name : String,
) -> Result[@ros.ParticipantEntitiesInfo, String] {
  let node = match @ros.NodeEntitiesInfo::new(node_namespace, node_name) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  for endpoint in self.local_endpoints {
    if endpoint.topic_name() == @ros.ROS_DISCOVERY_INFO_TOPIC_NAME {
      continue
    }
    let gid = @ros.Gid::from_guid(endpoint.endpoint_guid())
    match endpoint.kind() {
      @rtps.SedpEndpointKind::Publication => node.add_writer_gid(gid)
      @rtps.SedpEndpointKind::Subscription => node.add_reader_gid(gid)
    }
  }
  let info = @ros.ParticipantEntitiesInfo::new(
    @ros.Gid::from_guid(self.participant.participant_guid()),
  )
  info.add_node(node)
  Ok(info)
}

///|
/// Register and announce one local SEDP endpoint.
///
/// The participant GUID in the endpoint is normalized to the local participant
/// GUID. The endpoint is retained so it can be announced to participants that
/// are discovered later.
pub async fn RosParticipant::register_endpoint(
  self : RosParticipant,
  endpoint : @rtps.SedpEndpointData,
) -> Result[Unit, String] {
  let registered = endpoint.with_participant_guid(
    self.participant.participant_guid(),
  )
  for existing in self.local_endpoints {
    if existing.endpoint_guid() == registered.endpoint_guid() {
      return Err("the SEDP endpoint is already registered")
    }
  }
  self.local_endpoints.push(registered)
  self.discovery.announce_sedp_to_all(registered)
}

///|
/// Create, locate, register, and announce one ROS topic endpoint.
pub async fn RosParticipant::register_topic_endpoint(
  self : RosParticipant,
  topic : @ros.RosTopic,
  kind : @rtps.SedpEndpointKind,
  endpoint_id : @rtps.EntityId,
  qos : @rtps.SedpQos,
) -> Result[Unit, String] {
  let endpoint = match
    topic.to_sedp_with_qos(
      kind,
      @rtps.Guid::new(self.participant.participant_guid().prefix(), endpoint_id),
      qos,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  endpoint.add_unicast_locator(self.user_locator)
  self.register_endpoint(endpoint)
}

///|
/// Register the reliable ROS graph-discovery publication and subscription.
pub async fn RosParticipant::register_ros_discovery_info(
  self : RosParticipant,
  publication_id : @rtps.EntityId,
  subscription_id : @rtps.EntityId,
) -> Result[Unit, String] {
  let prefix = self.participant.participant_guid().prefix()
  let publication = match
    @ros.ros_discovery_info_to_sedp(
      @rtps.SedpEndpointKind::Publication,
      @rtps.Guid::new(prefix, publication_id),
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  publication.add_unicast_locator(self.user_locator)
  match self.register_endpoint(publication) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let subscription = match
    @ros.ros_discovery_info_to_sedp(
      @rtps.SedpEndpointKind::Subscription,
      @rtps.Guid::new(prefix, subscription_id),
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  subscription.add_unicast_locator(self.user_locator)
  self.register_endpoint(subscription)
}

///|
/// Send one SPDP participant announcement.
pub async fn RosParticipant::announce_spdp_once(
  self : RosParticipant,
) -> Result[Unit, String] {
  self.discovery.announce_once()
}

///|
/// Receive one SPDP or SEDP event and ingest it into the graph.
pub async fn RosParticipant::receive_discovery_once(
  self : RosParticipant,
) -> Result[(@socket.Addr, DiscoveryEvent), String] {
  let (source, event) = match self.discovery.receive_once() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match event {
    DiscoveryEvent::Participant(remote_participant) =>
      if remote_participant.participant_guid() !=
        self.participant.participant_guid() {
        for endpoint in self.local_endpoints {
          match
            self.discovery.announce_sedp_once(endpoint, remote_participant) {
            Ok(_) => ()
            Err(message) => return Err(message)
          }
        }
      }
    DiscoveryEvent::Publication(_) => ()
    DiscoveryEvent::Subscription(_) => ()
  }
  Ok((source, event))
}

///|
/// Transfer ownership of both underlying services to the caller.
pub fn RosParticipant::into_parts(
  self : RosParticipant,
) -> (DiscoveryService, Udp) {
  (self.discovery, self.user_socket)
}

///|
/// Close both discovery and user-data sockets.
pub fn RosParticipant::close(self : RosParticipant) -> Unit {
  self.discovery.close()
  self.user_socket.close()
}
