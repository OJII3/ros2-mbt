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
  mut local_endpoints : Array[@rtps.SedpEndpointData]
  mut spdp_socket : Udp?
  mut graph_publication_id : @rtps.EntityId?
  mut graph_subscription_id : @rtps.EntityId?
  mut ros_node_namespace : String?
  mut ros_node_name : String?
  mut latest_graph_info : @ros.ParticipantEntitiesInfo?
  mut graph_publishers : Array[ReliableRosDiscoveryPublisher]
  mut graph_publisher_guids : Array[@rtps.Guid]
  mut graph_subscriptions : Array[ReliableRosDiscoverySubscription]
  mut graph_subscription_guids : Array[@rtps.Guid]
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
    spdp_socket: None,
    graph_publication_id: None,
    graph_subscription_id: None,
    ros_node_namespace: None,
    ros_node_name: None,
    latest_graph_info: None,
    graph_publishers: [],
    graph_publisher_guids: [],
    graph_subscriptions: [],
    graph_subscription_guids: [],
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
  let discovery_receive_socket = match Udp::ddsi_spdp_multicast(domain_id) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let discovery_send_socket = Udp::bind(@socket.Addr::new(0, 0))
  let spdp_send_socket = Udp::bind(@socket.Addr::new(0, 0))
  let metatraffic_socket = match
    Udp::ddsi_spdp_unicast(domain_id, participant_id, ip) {
    Ok(value) => value
    Err(message) => {
      discovery_receive_socket.close()
      discovery_send_socket.close()
      spdp_send_socket.close()
      return Err(message)
    }
  }
  let user_socket = match
    Udp::ddsi_user_unicast(domain_id, participant_id, ip) {
    Ok(value) => value
    Err(message) => {
      discovery_receive_socket.close()
      discovery_send_socket.close()
      spdp_send_socket.close()
      metatraffic_socket.close()
      return Err(message)
    }
  }
  let session = match
    DiscoverySession::new_default_with_receive_sockets(
      discovery_send_socket,
      [discovery_receive_socket, metatraffic_socket],
      participant,
      domain_id,
      first_sequence_number,
    ) {
    Ok(value) => value
    Err(message) => {
      discovery_receive_socket.close()
      discovery_send_socket.close()
      spdp_send_socket.close()
      metatraffic_socket.close()
      user_socket.close()
      return Err(message)
    }
  }
  let result = match RosParticipant::from_discovery_session(session, user_socket) {
    Ok(value) => value
    Err(message) => {
      spdp_send_socket.close()
      return Err(message)
    }
  }
  result.spdp_socket = Some(spdp_send_socket)
  Ok(result)
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
/// Return a graph-discovery sample for the configured ROS node identity.
fn RosParticipant::configured_ros_discovery_info(
  self : RosParticipant,
) -> Result[@ros.ParticipantEntitiesInfo, String] {
  match (self.ros_node_namespace, self.ros_node_name) {
    (Some(node_namespace), Some(node_name)) =>
      self.participant_entities_info(node_namespace, node_name)
    _ => Err("the ROS node identity has not been configured")
  }
}

///|
/// Refresh the cached graph-discovery sample and publish it when possible.
async fn RosParticipant::refresh_ros_discovery_info(
  self : RosParticipant,
) -> Result[Unit, String] {
  let info = match self.configured_ros_discovery_info() {
    Ok(value) => value
    Err(message) if message == "the ROS node identity has not been configured" => {
      self.latest_graph_info = None
      return Ok(())
    }
    Err(message) => return Err(message)
  }
  self.latest_graph_info = Some(info)
  if self.graph_publication_id is None {
    return Ok(())
  }
  for publisher in self.graph_publishers {
    match publisher.announce_once(info) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(())
}

///|
/// Configure the ROS node identity used for automatic graph discovery.
///
/// The current endpoint set is cached immediately. Subsequent endpoint
/// registration and removal refresh this sample automatically.
pub async fn RosParticipant::set_ros_node_identity(
  self : RosParticipant,
  node_namespace : String,
  node_name : String,
) -> Result[Unit, String] {
  match @ros.NodeEntitiesInfo::new(node_namespace, node_name) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  self.ros_node_namespace = Some(node_namespace)
  self.ros_node_name = Some(node_name)
  self.refresh_ros_discovery_info()
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
  match self.discovery.announce_sedp_to_all(registered) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  self.refresh_ros_discovery_info()
}

///|
/// Dispose and forget one locally registered SEDP endpoint.
pub async fn RosParticipant::unregister_endpoint(
  self : RosParticipant,
  endpoint_guid : @rtps.Guid,
) -> Result[Unit, String] {
  let mut endpoint_index = -1
  for index in 0..<self.local_endpoints.length() {
    if self.local_endpoints[index].endpoint_guid() == endpoint_guid {
      endpoint_index = index
      break
    }
  }
  if endpoint_index < 0 {
    return Err("the SEDP endpoint is not registered")
  }
  let endpoint = self.local_endpoints[endpoint_index]
  match self.discovery.dispose_sedp_to_all(endpoint) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let remaining : Array[@rtps.SedpEndpointData] = []
  for index in 0..<self.local_endpoints.length() {
    if index != endpoint_index {
      remaining.push(self.local_endpoints[index])
    }
  }
  self.local_endpoints = remaining
  let prefix = self.participant.participant_guid().prefix()
  match self.graph_publication_id {
    Some(id) if endpoint_guid == @rtps.Guid::new(prefix, id) => {
      self.graph_publication_id = None
      self.graph_publishers = []
      self.graph_publisher_guids = []
      self.latest_graph_info = None
    }
    _ => ()
  }
  match self.graph_subscription_id {
    Some(id) if endpoint_guid == @rtps.Guid::new(prefix, id) => {
      self.graph_subscription_id = None
      self.graph_subscriptions = []
      self.graph_subscription_guids = []
    }
    _ => ()
  }
  self.refresh_ros_discovery_info()
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
/// Create, locate, register, and announce a ROS topic endpoint with its
/// RIHS01 type hash in the SEDP USER_DATA parameter.
pub async fn RosParticipant::register_topic_endpoint_with_type_hash(
  self : RosParticipant,
  topic : @ros.RosTopic,
  kind : @rtps.SedpEndpointKind,
  endpoint_id : @rtps.EntityId,
  qos : @rtps.SedpQos,
  type_hash : String,
) -> Result[Unit, String] {
  let endpoint = match
    topic.to_sedp_with_qos_and_type_hash(
      kind,
      @rtps.Guid::new(self.participant.participant_guid().prefix(), endpoint_id),
      qos,
      type_hash,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  endpoint.add_unicast_locator(self.user_locator)
  self.register_endpoint(endpoint)
}

///|
/// Register a ROS service server with optional request/response type hashes.
async fn RosParticipant::register_service_server_with_optional_type_hashes(
  self : RosParticipant,
  service : @ros.RosService,
  request_reader_id : @rtps.EntityId,
  response_writer_id : @rtps.EntityId,
  request_type_hash : String?,
  response_type_hash : String?,
) -> Result[Unit, String] {
  let prefix = self.participant.participant_guid().prefix()
  let request_guid = @rtps.Guid::new(prefix, request_reader_id)
  let response_guid = @rtps.Guid::new(prefix, response_writer_id)
  let request = match
    service.request_to_sedp_with_related_endpoint(
      @rtps.SedpEndpointKind::Subscription,
      request_guid,
      response_guid,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match request_type_hash {
    Some(type_hash) =>
      request.add_parameter(@rtps.qos_user_data_type_hash(type_hash))
    None => ()
  }
  request.add_unicast_locator(self.user_locator)
  match self.register_endpoint(request) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let response = match
    service.response_to_sedp_with_related_endpoint(
      @rtps.SedpEndpointKind::Publication,
      response_guid,
      request_guid,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match response_type_hash {
    Some(type_hash) =>
      response.add_parameter(@rtps.qos_user_data_type_hash(type_hash))
    None => ()
  }
  response.add_unicast_locator(self.user_locator)
  self.register_endpoint(response)
}

///|
/// Register the request reader and response writer for a ROS service server.
pub async fn RosParticipant::register_service_server(
  self : RosParticipant,
  service : @ros.RosService,
  request_reader_id : @rtps.EntityId,
  response_writer_id : @rtps.EntityId,
) -> Result[Unit, String] {
  self.register_service_server_with_optional_type_hashes(
    service,
    request_reader_id,
    response_writer_id,
    None,
    None,
  )
}

///|
/// Register a ROS service server and advertise request/response type hashes.
pub async fn RosParticipant::register_service_server_with_type_hashes(
  self : RosParticipant,
  service : @ros.RosService,
  request_reader_id : @rtps.EntityId,
  response_writer_id : @rtps.EntityId,
  request_type_hash : String,
  response_type_hash : String,
) -> Result[Unit, String] {
  self.register_service_server_with_optional_type_hashes(
    service,
    request_reader_id,
    response_writer_id,
    Some(request_type_hash),
    Some(response_type_hash),
  )
}

///|
/// Register a ROS service client with optional request/response type hashes.
async fn RosParticipant::register_service_client_with_optional_type_hashes(
  self : RosParticipant,
  service : @ros.RosService,
  request_writer_id : @rtps.EntityId,
  response_reader_id : @rtps.EntityId,
  request_type_hash : String?,
  response_type_hash : String?,
) -> Result[Unit, String] {
  let prefix = self.participant.participant_guid().prefix()
  let request_guid = @rtps.Guid::new(prefix, request_writer_id)
  let response_guid = @rtps.Guid::new(prefix, response_reader_id)
  let request = match
    service.request_to_sedp_with_related_endpoint(
      @rtps.SedpEndpointKind::Publication,
      request_guid,
      response_guid,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match request_type_hash {
    Some(type_hash) =>
      request.add_parameter(@rtps.qos_user_data_type_hash(type_hash))
    None => ()
  }
  request.add_unicast_locator(self.user_locator)
  match self.register_endpoint(request) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let response = match
    service.response_to_sedp_with_related_endpoint(
      @rtps.SedpEndpointKind::Subscription,
      response_guid,
      request_guid,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match response_type_hash {
    Some(type_hash) =>
      response.add_parameter(@rtps.qos_user_data_type_hash(type_hash))
    None => ()
  }
  response.add_unicast_locator(self.user_locator)
  self.register_endpoint(response)
}

///|
/// Register the request writer and response reader for a ROS service client.
pub async fn RosParticipant::register_service_client(
  self : RosParticipant,
  service : @ros.RosService,
  request_writer_id : @rtps.EntityId,
  response_reader_id : @rtps.EntityId,
) -> Result[Unit, String] {
  self.register_service_client_with_optional_type_hashes(
    service,
    request_writer_id,
    response_reader_id,
    None,
    None,
  )
}

///|
/// Register a ROS service client and advertise request/response type hashes.
pub async fn RosParticipant::register_service_client_with_type_hashes(
  self : RosParticipant,
  service : @ros.RosService,
  request_writer_id : @rtps.EntityId,
  response_reader_id : @rtps.EntityId,
  request_type_hash : String,
  response_type_hash : String,
) -> Result[Unit, String] {
  self.register_service_client_with_optional_type_hashes(
    service,
    request_writer_id,
    response_reader_id,
    Some(request_type_hash),
    Some(response_type_hash),
  )
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
  match self.register_endpoint(subscription) {
    Ok(_) => {
      self.graph_publication_id = Some(publication_id)
      self.graph_subscription_id = Some(subscription_id)
      self.reconcile_ros_discovery_endpoints()
    }
    Err(message) => Err(message)
  }
}

///|
/// Return the number of remote ROS graph publishers discovered so far.
pub fn RosParticipant::ros_discovery_publisher_count(
  self : RosParticipant,
) -> Int {
  self.graph_publishers.length()
}

///|
/// Return the number of remote ROS graph subscriptions discovered so far.
pub fn RosParticipant::ros_discovery_subscription_count(
  self : RosParticipant,
) -> Int {
  self.graph_subscriptions.length()
}

///|
/// Publish one local graph-discovery sample to every discovered subscription.
pub async fn RosParticipant::publish_ros_discovery_info(
  self : RosParticipant,
  info : @ros.ParticipantEntitiesInfo,
) -> Result[Unit, String] {
  self.latest_graph_info = Some(info)
  if self.graph_publishers.length() == 0 {
    return Err("no remote ROS graph subscriptions have been discovered")
  }
  for publisher in self.graph_publishers {
    match publisher.announce_once(info) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(())
}

///|
/// Receive one graph-discovery sample from a discovered publication.
pub async fn RosParticipant::receive_ros_discovery_info(
  self : RosParticipant,
  index : Int,
) -> Result[(@ros.ParticipantEntitiesInfo, @socket.Addr), String] {
  if index < 0 || index >= self.graph_subscriptions.length() {
    return Err("ROS graph subscription index is out of range")
  }
  let (info, source) = match self.graph_subscriptions[index].receive() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  self.discovery.ingest_ros_discovery_info(info)
  Ok((info, source))
}

///|
/// Receive and acknowledge one graph-discovery HEARTBEAT.
pub async fn RosParticipant::receive_ros_discovery_heartbeat(
  self : RosParticipant,
  index : Int,
) -> Result[(@rtps.HeartbeatSubmessage, @socket.Addr), String] {
  if index < 0 || index >= self.graph_subscriptions.length() {
    return Err("ROS graph subscription index is out of range")
  }
  self.graph_subscriptions[index].receive_heartbeat()
}

///|
/// Receive an ACKNACK for one graph publisher and retransmit requested data.
pub async fn RosParticipant::receive_ros_discovery_acknack(
  self : RosParticipant,
  index : Int,
) -> Result[(@rtps.AckNackSubmessage, @socket.Addr), String] {
  if index < 0 || index >= self.graph_publishers.length() {
    return Err("ROS graph publisher index is out of range")
  }
  self.graph_publishers[index].receive_acknack()
}

///|
/// Receive a NACK_FRAG for one graph publisher and retransmit its fragments.
pub async fn RosParticipant::receive_ros_discovery_nackfrag(
  self : RosParticipant,
  index : Int,
) -> Result[(@rtps.NackFragSubmessage, @socket.Addr), String] {
  if index < 0 || index >= self.graph_publishers.length() {
    return Err("ROS graph publisher index is out of range")
  }
  self.graph_publishers[index].receive_nackfrag()
}

///|
/// Receive either reliable control message for one graph publisher.
pub async fn RosParticipant::receive_ros_discovery_control(
  self : RosParticipant,
  index : Int,
) -> Result[Unit, String] {
  if index < 0 || index >= self.graph_publishers.length() {
    return Err("ROS graph publisher index is out of range")
  }
  self.graph_publishers[index].receive_control()
}

///|
/// Send one SPDP participant announcement.
pub async fn RosParticipant::announce_spdp_once(
  self : RosParticipant,
) -> Result[Unit, String] {
  match self.spdp_socket {
    Some(socket) => self.discovery.session.announce_once_on(socket)
    None => self.discovery.announce_once()
  }
}

///|
/// Announce the local participant until the surrounding async task is stopped.
pub async fn RosParticipant::announce_spdp_forever(
  self : RosParticipant,
  interval_ms : Int,
) -> Result[Unit, String] {
  if interval_ms <= 0 {
    return Err("the discovery announcement interval must be positive")
  }
  while true {
    match self.announce_spdp_once() {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    @async.sleep(interval_ms)
  }
  Ok(())
}

///| Send SEDP/SPDP disposal samples and close all participant sockets.
pub async fn RosParticipant::dispose_and_close(
  self : RosParticipant,
) -> Result[Unit, String] {
  for endpoint in self.local_endpoints {
    match self.discovery.dispose_sedp_to_all(endpoint) {
      Ok(_) => ()
      Err(message) => {
        self.close()
        return Err(message)
      }
    }
  }
  let spdp_result = match self.spdp_socket {
    Some(socket) => self.discovery.session.dispose_once_on(socket)
    None => self.discovery.session.dispose_once()
  }
  match spdp_result {
    Ok(_) => {
      self.close()
      Ok(())
    }
    Err(message) => {
      self.close()
      Err(message)
    }
  }
}

///| Forget a removed ROS graph publication and its reliable reader.
fn RosParticipant::forget_graph_publication(
  self : RosParticipant,
  endpoint_guid : @rtps.Guid,
) -> Unit {
  let guids : Array[@rtps.Guid] = []
  let subscriptions : Array[ReliableRosDiscoverySubscription] = []
  for index in 0..<self.graph_subscription_guids.length() {
    if self.graph_subscription_guids[index] == endpoint_guid {
      continue
    }
    guids.push(self.graph_subscription_guids[index])
    subscriptions.push(self.graph_subscriptions[index])
  }
  self.graph_subscription_guids = guids
  self.graph_subscriptions = subscriptions
}

///| Forget a removed ROS graph subscription and its reliable writer.
fn RosParticipant::forget_graph_subscription(
  self : RosParticipant,
  endpoint_guid : @rtps.Guid,
) -> Unit {
  let guids : Array[@rtps.Guid] = []
  let publishers : Array[ReliableRosDiscoveryPublisher] = []
  for index in 0..<self.graph_publisher_guids.length() {
    if self.graph_publisher_guids[index] == endpoint_guid {
      continue
    }
    guids.push(self.graph_publisher_guids[index])
    publishers.push(self.graph_publishers[index])
  }
  self.graph_publisher_guids = guids
  self.graph_publishers = publishers
}

///| Forget all ROS graph sessions owned by one remote participant.
fn RosParticipant::forget_graph_participant(
  self : RosParticipant,
  participant_prefix : @rtps.GuidPrefix,
) -> Unit {
  let subscription_guids : Array[@rtps.Guid] = []
  let subscriptions : Array[ReliableRosDiscoverySubscription] = []
  for index in 0..<self.graph_subscription_guids.length() {
    if self.graph_subscription_guids[index].prefix() == participant_prefix {
      continue
    }
    subscription_guids.push(self.graph_subscription_guids[index])
    subscriptions.push(self.graph_subscriptions[index])
  }
  self.graph_subscription_guids = subscription_guids
  self.graph_subscriptions = subscriptions
  let publisher_guids : Array[@rtps.Guid] = []
  let publishers : Array[ReliableRosDiscoveryPublisher] = []
  for index in 0..<self.graph_publisher_guids.length() {
    if self.graph_publisher_guids[index].prefix() == participant_prefix {
      continue
    }
    publisher_guids.push(self.graph_publisher_guids[index])
    publishers.push(self.graph_publishers[index])
  }
  self.graph_publisher_guids = publisher_guids
  self.graph_publishers = publishers
}

///| Ensure one already-known ROS graph publication has a reliable reader.
fn RosParticipant::ensure_ros_discovery_publication(
  self : RosParticipant,
  publication : @rtps.SedpEndpointData,
) -> Result[Unit, String] {
  if publication.topic_name() != @ros.ROS_DISCOVERY_INFO_TOPIC_NAME ||
    publication.type_name() != @ros.ROS_DISCOVERY_INFO_TYPE_NAME {
    return Ok(())
  }
  let reader_id = match self.graph_subscription_id {
    Some(value) => value
    None => return Ok(())
  }
  let endpoint_guid = publication.endpoint_guid()
  for guid in self.graph_subscription_guids {
    if guid == endpoint_guid {
      return Ok(())
    }
  }
  let reader = match
    ReliableRosDiscoverySubscription::new_for_publication(
      self.user_socket,
      self.participant.participant_guid().prefix(),
      self.participant.vendor_id(),
      reader_id,
      publication,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  self.graph_subscriptions.push(reader)
  self.graph_subscription_guids.push(endpoint_guid)
  Ok(())
}

///| Ensure one already-known ROS graph subscription has a reliable writer.
async fn RosParticipant::ensure_ros_discovery_subscription(
  self : RosParticipant,
  subscription : @rtps.SedpEndpointData,
  announce_initial : Bool,
) -> Result[Unit, String] {
  if subscription.topic_name() != @ros.ROS_DISCOVERY_INFO_TOPIC_NAME ||
    subscription.type_name() != @ros.ROS_DISCOVERY_INFO_TYPE_NAME {
    return Ok(())
  }
  let writer_id = match self.graph_publication_id {
    Some(value) => value
    None => return Ok(())
  }
  let endpoint_guid = subscription.endpoint_guid()
  for guid in self.graph_publisher_guids {
    if guid == endpoint_guid {
      return Ok(())
    }
  }
  let publisher = match
    ReliableRosDiscoveryPublisher::new_for_subscription(
      self.user_socket,
      self.participant.participant_guid().prefix(),
      self.participant.vendor_id(),
      writer_id,
      subscription,
      1L,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if announce_initial {
    let info = match self.latest_graph_info {
      Some(info) => Some(info)
      None => match self.configured_ros_discovery_info() {
        Ok(info) => {
          self.latest_graph_info = Some(info)
          Some(info)
        }
        Err(_) => None
      }
    }
    match info {
      Some(info) => match publisher.announce_once(info) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
      None => ()
    }
  }
  self.graph_publishers.push(publisher)
  self.graph_publisher_guids.push(endpoint_guid)
  Ok(())
}

///| Reconcile graph endpoints received before local graph endpoints were set up.
async fn RosParticipant::reconcile_ros_discovery_endpoints(
  self : RosParticipant,
) -> Result[Unit, String] {
  let graph = self.graph()
  for publication in graph.publications() {
    match self.ensure_ros_discovery_publication(publication) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  for subscription in graph.subscriptions() {
    match self.ensure_ros_discovery_subscription(subscription, false) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  self.refresh_ros_discovery_info()
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
    DiscoveryEvent::Publication(publication) =>
      match self.ensure_ros_discovery_publication(publication) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    DiscoveryEvent::Subscription(subscription) =>
      match self.ensure_ros_discovery_subscription(subscription, true) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    DiscoveryEvent::EndpointRemoved(kind, endpoint_guid) =>
      match kind {
        @rtps.SedpEndpointKind::Publication =>
          self.forget_graph_publication(endpoint_guid)
        @rtps.SedpEndpointKind::Subscription =>
          self.forget_graph_subscription(endpoint_guid)
      }
    DiscoveryEvent::ParticipantRemoved(participant_guid) =>
      self.forget_graph_participant(participant_guid.prefix())
  }
  Ok((source, event))
}

///|
/// Transfer ownership of both underlying services to the caller.
pub fn RosParticipant::into_parts(
  self : RosParticipant,
) -> (DiscoveryService, Udp) {
  match self.spdp_socket {
    Some(socket) => socket.close()
    None => ()
  }
  (self.discovery, self.user_socket)
}

///|
/// Close both discovery and user-data sockets.
pub fn RosParticipant::close(self : RosParticipant) -> Unit {
  self.discovery.close()
  match self.spdp_socket {
    Some(socket) => socket.close()
    None => ()
  }
  self.user_socket.close()
}
