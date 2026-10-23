///|
/// Internal middleware-facing metadata for a ROS topic endpoint.
/// It deliberately contains ROS names and serialized-message QoS only; the
/// RTPS endpoint identifiers stay inside this package's adapter.
priv struct MiddlewareEndpointInfo {
  topic_name : String
  type_name : String
  type_hash : String
  reliability : Bool
  transient_local : Bool
}

///|
/// QoS policies understood by the ROS-facing middleware boundary.
priv struct MiddlewareQos {
  reliable : Bool
  transient_local : Bool
}

///|
/// Backend adapter owned by a ROS node. The RTPS participant remains private
/// behind this boundary for lifecycle and local endpoint registration.
priv struct RosMiddleware {
  backend : RosParticipant
}

///|
/// Received user data kept opaque to the executor and ROS node.
priv struct MiddlewareIncoming {
  message : @rtps.Message
  source : @socket.Addr
}

///|
/// Discovery input kept opaque to the executor.
priv struct MiddlewareDiscovery {
  event : @wire.DiscoveryEvent
}

///|
fn RosMiddleware::new(backend : RosParticipant) -> RosMiddleware {
  { backend, }
}

///|
async fn RosMiddleware::set_node_identity(
  self : RosMiddleware,
  node_namespace : String,
  name : String,
) -> Result[Unit, String] {
  self.backend.set_ros_node_identity(node_namespace, name)
}

///|
async fn RosMiddleware::register_topic(
  self : RosMiddleware,
  topic : @ros_types.RosTopic,
  kind : @rtps.SedpEndpointKind,
  id : @rtps.EntityId,
  qos : MiddlewareQos,
  type_hash : String,
) -> Result[Unit, String] {
  let backend_qos = @rtps.SedpQos::new(
    if qos.reliable {
      @rtps.RELIABILITY_RELIABLE
    } else {
      @rtps.RELIABILITY_BEST_EFFORT
    },
    if qos.transient_local {
      @rtps.DURABILITY_TRANSIENT_LOCAL
    } else {
      @rtps.DURABILITY_VOLATILE
    },
    @rtps.HISTORY_KEEP_LAST,
    10,
  )
  self.backend.register_topic_endpoint_with_type_hash(
    topic, kind, id, backend_qos, type_hash,
  )
}

///|
async fn RosMiddleware::register_ros_discovery_info(
  self : RosMiddleware,
  publication_id : @rtps.EntityId,
  subscription_id : @rtps.EntityId,
) -> Result[Unit, String] {
  self.backend.register_ros_discovery_info(publication_id, subscription_id)
}

///|
async fn RosMiddleware::create_publisher(
  self : RosMiddleware,
  topic : @ros_types.RosTopic,
  type_hash : String,
  qos : MiddlewareQos,
  writer_id : @rtps.EntityId,
) -> Result[MiddlewarePublisher, String] {
  if qos.transient_local {
    return Err("only volatile durability is supported for user topics")
  }
  let writer = match
    ReliableRosPublisher::new(
      topic,
      self.backend.user_socket(),
      self.backend.participant().participant_guid().prefix(),
      self.backend.participant().vendor_id(),
      writer_id,
      1L,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match self.register_topic(topic, Publication, writer_id, qos, type_hash) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(MiddlewarePublisher::new(writer, topic, type_hash, qos))
}

///|
async fn RosMiddleware::register_subscription(
  self : RosMiddleware,
  topic : @ros_types.RosTopic,
  type_hash : String,
  qos : MiddlewareQos,
  reader_id : @rtps.EntityId,
) -> Result[Unit, String] {
  self.register_topic(topic, Subscription, reader_id, qos, type_hash)
}

///|
fn MiddlewarePublisher::matches(
  self : MiddlewarePublisher,
  endpoint : @rtps.SedpEndpointData,
) -> Bool {
  if endpoint.topic_name() != self.info.topic_name ||
    endpoint.type_name() != self.info.type_name {
    return false
  }
  match endpoint.type_hash() {
    Ok(Some(hash)) =>
      if self.info.type_hash != "" && hash != self.info.type_hash {
        return false
      }
    _ => ()
  }
  match endpoint.qos() {
    Ok(requested) => {
      let offered = {
        reliable: self.info.reliability,
        transient_local: self.info.transient_local,
      }
      MiddlewareQos::from_backend(requested).compatible_with(offered) &&
      ros_endpoint_has_udp_v4_locator(endpoint)
    }
    Err(_) => false
  }
}

///|
fn RosMiddleware::create_reader(
  self : RosMiddleware,
  topic : @ros_types.RosTopic,
  reader_id : @rtps.EntityId,
  qos : MiddlewareQos,
  publication : @rtps.SedpEndpointData,
) -> Result[MiddlewareReader, String] {
  let offered = match publication.qos() {
    Ok(value) => MiddlewareQos::from_backend(value)
    Err(message) => return Err(message)
  }
  if publication.topic_name() != topic.dds_name() ||
    publication.type_name() != topic.dds_type_name() {
    return Err("the discovered publication does not match the topic")
  }
  if !qos.compatible_with(offered) {
    return Err("the discovered publication has incompatible QoS")
  }
  MiddlewareReader::new(
    topic,
    self.backend.user_socket(),
    self.backend.participant().participant_guid().prefix(),
    self.backend.participant().vendor_id(),
    reader_id,
    publication,
    qos.reliable,
  )
}

///|
fn middleware_matches_reader(
  topic : @ros_types.RosTopic,
  qos : MiddlewareQos,
  publication : @rtps.SedpEndpointData,
) -> Bool {
  if publication.topic_name() != topic.dds_name() ||
    publication.type_name() != topic.dds_type_name() ||
    !ros_endpoint_has_udp_v4_locator(publication) {
    return false
  }
  match publication.qos() {
    Ok(offered) => qos.compatible_with(MiddlewareQos::from_backend(offered))
    Err(_) => false
  }
}

///|
fn RosMiddleware::graph(self : RosMiddleware) -> @discovery.DiscoveryGraph {
  self.backend.graph()
}

///|
fn RosMiddleware::participant_guid(self : RosMiddleware) -> @rtps.Guid {
  self.backend.participant().participant_guid()
}

///|

///|
fn RosMiddleware::close(self : RosMiddleware) -> Unit {
  self.backend.close()
}

///|
async fn RosMiddleware::dispose_and_close(
  self : RosMiddleware,
) -> Result[Unit, String] {
  self.backend.dispose_and_close()
}

///|
async fn RosMiddleware::receive_discovery_once(
  self : RosMiddleware,
) -> Result[MiddlewareDiscovery, String] {
  let (_, event) = match self.backend.receive_discovery_once() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ event, })
}

///|
async fn RosMiddleware::wait_datagram(
  self : RosMiddleware,
) -> Result[MiddlewareIncoming, String] {
  let (message, source) = match self.backend.user_socket().receive_message() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ message, source, })
}

///|
async fn RosMiddleware::send_discovery_heartbeats(
  self : RosMiddleware,
) -> Result[Unit, String] {
  self.backend.send_ros_discovery_heartbeats()
}

///|
async fn RosMiddleware::handle_datagram(
  self : RosMiddleware,
  incoming : MiddlewareIncoming,
) -> Result[Unit, String] {
  self.backend.handle_user_message(incoming.message, incoming.source)
}

///|
async fn RosMiddleware::announce_spdp_forever(
  self : RosMiddleware,
  period_ms : Int32,
) -> Result[Unit, String] {
  self.backend.announce_spdp_forever(period_ms)
}

///|
fn MiddlewareQos::from_backend(qos : @rtps.SedpQos) -> MiddlewareQos {
  {
    reliable: qos.reliability() == @rtps.RELIABILITY_RELIABLE,
    transient_local: qos.durability() != @rtps.DURABILITY_VOLATILE,
  }
}

///|
fn MiddlewareQos::compatible_with(
  self : MiddlewareQos,
  offered : MiddlewareQos,
) -> Bool {
  (!self.reliable || offered.reliable) &&
  (!self.transient_local || offered.transient_local)
}

///|
/// A publisher handle at the internal middleware boundary.
/// Callers exchange serialized payloads and do not need the RTPS writer type.
priv struct MiddlewarePublisher {
  writer : ReliableRosPublisher
  // Kept as a shared view for existing whitebox diagnostics.
  writers : Array[ReliableRosTarget]
  info : MiddlewareEndpointInfo
}

///|
/// An attached remote writer as seen by a middleware subscription.
priv struct MiddlewareReader {
  endpoint_guid : @rtps.Guid
  reader : MiddlewareReaderKind
}

///|
priv enum MiddlewareReaderKind {
  BestEffort(RosSubscription)
  Reliable(ReliableRosSubscription)
}

///|
fn MiddlewareReader::new(
  topic : @ros_types.RosTopic,
  socket : @wire.Udp,
  participant_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  reader_id : @rtps.EntityId,
  publication : @rtps.SedpEndpointData,
  reliable : Bool,
) -> Result[MiddlewareReader, String] {
  let endpoint_guid = publication.endpoint_guid()
  let reader = if reliable {
    let sub = match
      ReliableRosSubscription::new_for_publication(
        topic, socket, participant_prefix, vendor_id, reader_id, publication,
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    Reliable(sub)
  } else {
    let sub = match
      RosSubscription::new_for_publication_with_prefix(
        topic, socket, participant_prefix, reader_id, publication,
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    BestEffort(sub)
  }
  Ok({ endpoint_guid, reader, })
}

///|
async fn MiddlewareReader::take(
  self : MiddlewareReader,
  message : @rtps.Message,
  source : @socket.Addr,
) -> Result[Array[Bytes], String] {
  match self.reader {
    BestEffort(reader) => {
      let payload = match reader.handle_message(message, source) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      match payload {
        Some(value) => Ok([value])
        None => Ok([])
      }
    }
    Reliable(reader) => reader.handle_message(message, source)
  }
}

///|
async fn MiddlewareReader::take_incoming(
  self : MiddlewareReader,
  incoming : MiddlewareIncoming,
) -> Result[Array[Bytes], String] {
  self.take(incoming.message, incoming.source)
}

///|
fn MiddlewarePublisher::new(
  writer : ReliableRosPublisher,
  topic : @ros_types.RosTopic,
  type_hash : String,
  qos : MiddlewareQos,
) -> MiddlewarePublisher {
  {
    writer,
    writers: writer.writers,
    info: {
      topic_name: topic.dds_name(),
      type_name: topic.dds_type_name(),
      type_hash,
      reliability: qos.reliable,
      transient_local: qos.transient_local,
    },
  }
}

///|

///|
async fn MiddlewarePublisher::publish(
  self : MiddlewarePublisher,
  payload : Bytes,
) -> Result[Unit, String] {
  self.writer.publish(payload)
}

///|
async fn MiddlewarePublisher::send_heartbeat(
  self : MiddlewarePublisher,
) -> Result[Unit, String] {
  self.writer.send_heartbeat()
}

///|
fn MiddlewarePublisher::add_subscription(
  self : MiddlewarePublisher,
  subscription : @rtps.SedpEndpointData,
) -> Result[Unit, String] {
  if subscription.topic_name() != self.info.topic_name ||
    subscription.type_name() != self.info.type_name {
    return Err("the discovered subscription does not match the topic")
  }
  let requested = match subscription.qos() {
    Ok(value) => MiddlewareQos::from_backend(value)
    Err(message) => return Err(message)
  }
  if !requested.compatible_with({
      reliable: self.info.reliability,
      transient_local: self.info.transient_local,
    }) {
    return Err("the discovered subscription has incompatible QoS")
  }
  self.writer.add_subscription(subscription)
}

///|
fn MiddlewarePublisher::remove_subscription(
  self : MiddlewarePublisher,
  endpoint_guid : @rtps.Guid,
) -> Unit {
  self.writer.remove_subscription(endpoint_guid)
}

///|
fn MiddlewarePublisher::remove_subscriptions_from_participant(
  self : MiddlewarePublisher,
  prefix : @rtps.GuidPrefix,
) -> Unit {
  self.writer.remove_subscriptions_from_participant(prefix)
}

///|
async fn MiddlewarePublisher::handle_incoming(
  self : MiddlewarePublisher,
  incoming : MiddlewareIncoming,
) -> Result[Unit, String] {
  self.writer.handle_message(incoming.message)
}
