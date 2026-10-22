///|
/// State for local ROS graph publication and remote graph readers.
///
/// Kept separate from `RosParticipant` so graph discovery can evolve without
/// expanding the participant's socket and DDSI lifecycle state.
pub struct RosGraph {
  mut graph_publication_id : @rtps.EntityId?
  mut graph_subscription_id : @rtps.EntityId?
  mut ros_node_namespace : String?
  mut ros_node_name : String?
  mut latest_graph_info : @ros_types.ParticipantEntitiesInfo?
  mut graph_publishers : Array[ReliableRosDiscoveryPublisher]
  mut graph_publisher_guids : Array[@rtps.Guid]
  mut graph_subscriptions : Array[ReliableRosDiscoverySubscription]
  mut graph_subscription_guids : Array[@rtps.Guid]
}

///|
/// Create an empty ROS graph-discovery state.
fn RosGraph::new() -> RosGraph {
  {
    graph_publication_id: None,
    graph_subscription_id: None,
    ros_node_namespace: None,
    ros_node_name: None,
    latest_graph_info: None,
    graph_publishers: [],
    graph_publisher_guids: [],
    graph_subscriptions: [],
    graph_subscription_guids: [],
  }
}

///|
/// Build a participant graph sample from its registered local endpoints.
fn build_participant_entities_info(
  participant_guid : @rtps.Guid,
  endpoints : Array[@rtps.SedpEndpointData],
  node_namespace : String,
  node_name : String,
) -> Result[@ros_types.ParticipantEntitiesInfo, String] {
  let node = match @ros_types.NodeEntitiesInfo::new(node_namespace, node_name) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  for endpoint in endpoints {
    if endpoint.topic_name() == @ros_types.ROS_DISCOVERY_INFO_TOPIC_NAME {
      continue
    }
    let gid = @ros_types.Gid::from_guid(endpoint.endpoint_guid())
    match endpoint.kind() {
      Publication => node.add_writer_gid(gid)
      Subscription => node.add_reader_gid(gid)
    }
  }
  let info = @ros_types.ParticipantEntitiesInfo::new(
    @ros_types.Gid::from_guid(participant_guid),
  )
  info.add_node(node)
  Ok(info)
}

///|
/// Build a graph sample for the configured local ROS node identity.
fn RosGraph::configured_info(
  self : RosGraph,
  participant_guid : @rtps.Guid,
  endpoints : Array[@rtps.SedpEndpointData],
) -> Result[@ros_types.ParticipantEntitiesInfo, String] {
  match (self.ros_node_namespace, self.ros_node_name) {
    (Some(node_namespace), Some(name)) =>
      build_participant_entities_info(
        participant_guid, endpoints, node_namespace, name,
      )
    _ => Err("the ROS node identity has not been configured")
  }
}

///|
/// Publish and retain the current graph sample through every discovered writer.
async fn RosGraph::publish(
  self : RosGraph,
  info : @ros_types.ParticipantEntitiesInfo,
) -> Result[Unit, String] {
  self.latest_graph_info = Some(info)
  for publisher in self.graph_publishers {
    match publisher.announce_once(info) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(())
}

///|
/// Build and publish the graph sample for the configured local node, if any.
async fn RosGraph::refresh(
  self : RosGraph,
  participant_guid : @rtps.Guid,
  endpoints : Array[@rtps.SedpEndpointData],
) -> Result[Unit, String] {
  let info = match self.configured_info(participant_guid, endpoints) {
    Ok(value) => value
    Err(message) if message == "the ROS node identity has not been configured" => {
      self.latest_graph_info = None
      return Ok(())
    }
    Err(message) => return Err(message)
  }
  if self.graph_publication_id is None {
    self.latest_graph_info = Some(info)
    return Ok(())
  }
  self.publish(info)
}

///|
/// Forget one removed graph endpoint and its corresponding reliable session.
fn RosGraph::forget_endpoint(
  self : RosGraph,
  kind : @rtps.SedpEndpointKind,
  endpoint_guid : @rtps.Guid,
) -> Unit {
  match kind {
    Publication => {
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
    Subscription => {
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
  }
}

///|
/// Match a discovered ROS graph publication and create its reliable reader.
fn RosGraph::match_publication(
  self : RosGraph,
  publication : @rtps.SedpEndpointData,
  socket : @wire.Udp,
  participant_guid : @rtps.Guid,
  vendor_id : @rtps.VendorId,
) -> Result[Unit, String] {
  if publication.topic_name() != @ros_types.ROS_DISCOVERY_INFO_TOPIC_NAME ||
    publication.type_name() != @ros_types.ROS_DISCOVERY_INFO_TYPE_NAME {
    return Ok(())
  }
  match
    @ros_types.validate_ros_discovery_info_endpoint(publication, Publication) {
    Ok(_) => ()
    Err(_) => return Ok(())
  }
  let qos = match publication.qos() {
    Ok(value) => value
    Err(_) => return Ok(())
  }
  if qos.durability() != @rtps.DURABILITY_TRANSIENT_LOCAL ||
    !ros_endpoint_has_udp_v4_locator(publication) {
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
      socket,
      participant_guid.prefix(),
      vendor_id,
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

///|
/// Match a discovered ROS graph subscription and create its reliable writer.
async fn RosGraph::match_subscription(
  self : RosGraph,
  subscription : @rtps.SedpEndpointData,
  socket : @wire.Udp,
  participant_guid : @rtps.Guid,
  vendor_id : @rtps.VendorId,
  announce_initial : Bool,
  current_info : @ros_types.ParticipantEntitiesInfo?,
) -> Result[Unit, String] {
  if subscription.topic_name() != @ros_types.ROS_DISCOVERY_INFO_TOPIC_NAME ||
    subscription.type_name() != @ros_types.ROS_DISCOVERY_INFO_TYPE_NAME {
    return Ok(())
  }
  match
    @ros_types.validate_ros_discovery_info_endpoint(subscription, Subscription) {
    Ok(_) => ()
    Err(_) => return Ok(())
  }
  if !ros_endpoint_has_udp_v4_locator(subscription) {
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
      socket,
      participant_guid.prefix(),
      vendor_id,
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
      None => current_info
    }
    match info {
      Some(info) => {
        self.latest_graph_info = Some(info)
        match publisher.announce_once(info) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      }
      None => ()
    }
  }
  self.graph_publishers.push(publisher)
  self.graph_publisher_guids.push(endpoint_guid)
  Ok(())
}

///|
/// Match all retained remote ROS graph endpoints against local graph endpoints.
async fn RosGraph::reconcile_endpoints(
  self : RosGraph,
  publications : Array[@rtps.SedpEndpointData],
  subscriptions : Array[@rtps.SedpEndpointData],
  socket : @wire.Udp,
  participant_guid : @rtps.Guid,
  vendor_id : @rtps.VendorId,
) -> Result[Unit, String] {
  for publication in publications {
    match
      self.match_publication(publication, socket, participant_guid, vendor_id) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  for subscription in subscriptions {
    match
      self.match_subscription(
        subscription,
        socket,
        participant_guid,
        vendor_id,
        false,
        None,
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(())
}

///|
/// Forget graph readers and writers whose remote participant left discovery.
fn RosGraph::forget_participant(
  self : RosGraph,
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
