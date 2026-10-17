///|
/// A lightweight ROS node that groups topic entities and callbacks.
pub struct RosNode {
  priv participant : RosParticipant
  priv subscriptions : Array[RosNodeSubscription]
  priv publishers : Array[RosPublisher]
  priv timers : Array[RosNodeTimer]
  priv mut next_entity_key : UInt32
  priv mut executor_attached : Bool
}

///|
priv struct RosNodeReader {
  endpoint_guid : @rtps.Guid
  subscription : RosSubscription
}

///|
priv struct RosNodeSubscription {
  topic : @ros_types.RosTopic
  reader_id : @rtps.EntityId
  callback : async (Bytes) -> Result[Unit, String]
  mut readers : Array[RosNodeReader]
}

///|
priv struct RosNodeTimer {
  timer : @async.Timer
  callback : async () -> Unit
}

///|
/// A publisher returned by `RosNode::create_publisher`.
pub struct RosNodePublisher[T] {
  priv publisher : RosPublisher
  priv encoder : (T) -> Result[Bytes, String]
}

///|
/// Create a ROS node around a fresh DDSI participant.
///
/// This configures the ROS node identity and builtin ROS graph endpoints.
pub async fn RosNode::new(
  participant : RosParticipant,
  node_namespace : String,
  node_name : String,
) -> Result[RosNode, String] {
  match participant.set_ros_node_identity(node_namespace, node_name) {
    Ok(_) => ()
    Err(message) => {
      participant.close()
      return Err(message)
    }
  }
  let publication_id = match
    @rtps.EntityId::new(b"gph", @ros_types.ROS_GRAPH_PUBLICATION_ENTITY_KIND) {
    Ok(value) => value
    Err(message) => {
      participant.close()
      return Err(message)
    }
  }
  let subscription_id = match
    @rtps.EntityId::new(b"gph", @ros_types.ROS_GRAPH_SUBSCRIPTION_ENTITY_KIND) {
    Ok(value) => value
    Err(message) => {
      participant.close()
      return Err(message)
    }
  }
  match
    participant.register_ros_discovery_info(publication_id, subscription_id) {
    Ok(_) => ()
    Err(message) => {
      participant.close()
      return Err(message)
    }
  }
  Ok({
    participant,
    subscriptions: [],
    publishers: [],
    timers: [],
    next_entity_key: 1U,
    executor_attached: false,
  })
}

///|
/// Allocate a user-defined topic endpoint identifier.
fn RosNode::next_entity_id(
  self : RosNode,
  kind : Byte,
) -> Result[@rtps.EntityId, String] {
  if self.next_entity_key > 0xFFFFFFU {
    return Err("the ROS node exhausted its RTPS endpoint identifiers")
  }
  if self.next_entity_key == 0x677068U {
    self.next_entity_key += 1U
  }
  let key = self.next_entity_key
  self.next_entity_key += 1U
  @rtps.EntityId::new(
    Bytes::from_array([
      (key >> 16).to_byte(),
      (key >> 8).to_byte(),
      key.to_byte(),
    ]),
    kind,
  )
}

///|
/// Create a best-effort ROS topic publisher.
///
/// The encoder converts a message value to its serialized CDR payload.
pub async fn[T] RosNode::create_publisher(
  self : RosNode,
  topic : @ros_types.RosTopic,
  type_hash : String,
  encoder : (T) -> Result[Bytes, String],
) -> Result[RosNodePublisher[T], String] {
  let writer_id = match self.next_entity_id(0x03) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let qos = @rtps.SedpQos::new(
    @rtps.RELIABILITY_BEST_EFFORT,
    @rtps.DURABILITY_VOLATILE,
    @rtps.HISTORY_KEEP_LAST,
    10,
  )
  let publisher = match
    RosPublisher::new(
      topic,
      self.participant.user_socket(),
      self.participant.participant().participant_guid().prefix(),
      self.participant.participant().vendor_id(),
      writer_id,
      1L,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match
    self.participant.register_topic_endpoint_with_type_hash(
      topic,
      Publication,
      writer_id,
      qos,
      type_hash,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  self.publishers.push(publisher)
  let publisher_index = self.publishers.length() - 1
  let graph = self.participant.graph()
  for subscription in graph.subscriptions() {
    if subscription.topic_name() == topic.dds_name() &&
      subscription.type_name() == topic.dds_type_name() {
      let qos = match subscription.qos() {
        Ok(value) => value
        Err(_) => continue
      }
      if qos.reliability() != @rtps.RELIABILITY_BEST_EFFORT ||
        qos.durability() != @rtps.DURABILITY_VOLATILE ||
        !ros_endpoint_has_udp_v4_locator(subscription) {
        continue
      }
      match self.publishers[publisher_index].add_subscription(subscription) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    }
  }
  Ok({ publisher, encoder, })
}

///|
/// Serialize and publish one message.
pub async fn[T] RosNodePublisher::publish(
  self : RosNodePublisher[T],
  message : T,
) -> Result[Unit, String] {
  let payload = match (self.encoder)(message) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  self.publisher.publish(payload)
}

///|
/// Create a best-effort subscription with a typed message callback.
///
/// The decoder converts the serialized CDR payload to a message value.
pub async fn[T] RosNode::create_subscription(
  self : RosNode,
  topic : @ros_types.RosTopic,
  type_hash : String,
  decoder : (Bytes) -> Result[T, String],
  callback : async (T) -> Unit,
) -> Result[Unit, String] {
  let reader_id = match self.next_entity_id(0x04) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let message_callback : async (Bytes) -> Result[Unit, String] = async fn(
    payload,
  ) {
    let message = match decoder(payload) {
      Ok(value) => value
      Err(_) => return Ok(())
    }
    callback(message)
    Ok(())
  }
  let qos = @rtps.SedpQos::new(
    @rtps.RELIABILITY_BEST_EFFORT,
    @rtps.DURABILITY_VOLATILE,
    @rtps.HISTORY_KEEP_LAST,
    10,
  )
  match
    self.participant.register_topic_endpoint_with_type_hash(
      topic,
      Subscription,
      reader_id,
      qos,
      type_hash,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  self.subscriptions.push({
    topic,
    reader_id,
    callback: message_callback,
    readers: [],
  })
  let graph = self.participant.graph()
  for publication in graph.publications() {
    match self.add_publication(publication) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(())
}

///|
/// Add a discovered publication to matching local subscriptions.
fn RosNode::add_publication(
  self : RosNode,
  publication : @rtps.SedpEndpointData,
) -> Result[Unit, String] {
  for index in 0..<self.subscriptions.length() {
    let subscription = self.subscriptions[index]
    if subscription.topic.dds_name() != publication.topic_name() ||
      subscription.topic.dds_type_name() != publication.type_name() {
      continue
    }
    match publication.qos() {
      Ok(_) => ()
      Err(_) => continue
    }
    let endpoint_guid = publication.endpoint_guid()
    let mut already_added = false
    for reader in subscription.readers {
      if reader.endpoint_guid == endpoint_guid {
        already_added = true
        break
      }
    }
    if already_added {
      continue
    }
    let reader = match
      RosSubscription::new_for_publication_with_prefix(
        subscription.topic,
        self.participant.user_socket(),
        self.participant.participant().participant_guid().prefix(),
        subscription.reader_id,
        publication,
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    self.subscriptions[index].readers.push({
      endpoint_guid,
      subscription: reader,
    })
  }
  Ok(())
}

///|
/// Create a periodic callback driven by the executor.
pub fn RosNode::create_timer(
  self : RosNode,
  period_ms : Int32,
  callback : async () -> Unit,
) -> Result[Unit, String] {
  if period_ms <= 0 {
    return Err("a ROS timer period must be positive")
  }
  self.timers.push({ timer: @async.Timer(period_ms), callback, })
  Ok(())
}

///|
/// Close the participant owned by this node.
pub fn RosNode::close(self : RosNode) -> Unit {
  self.participant.close()
}

///|
/// Dispose the node's endpoints and close its participant.
pub async fn RosNode::dispose_and_close(self : RosNode) -> Result[Unit, String] {
  self.participant.dispose_and_close()
}

///|
/// One event selected by the executor's asynchronous wait loop.
priv enum RosExecutorEvent {
  Discovery(Int32, Result[(@socket.Addr, @wire.DiscoveryEvent), String])
  Datagram(Int32, Result[(@rtps.Message, @socket.Addr), String])
  Timer(Int32, Int32)
  Shutdown
}

///|
/// Drive ROS node discovery, best-effort topic traffic, timers, and callbacks.
pub struct Executor {
  priv nodes : Array[RosNode]
  priv shutdown_queue : @aqueue.Queue[Unit]
  priv mut running : Bool
  priv mut shutdown_requested : Bool
}

///|
/// Create an executor with no nodes attached.
pub fn Executor::new() -> Executor {
  {
    nodes: [],
    shutdown_queue: @aqueue.Queue(kind=@aqueue.Unbounded),
    running: false,
    shutdown_requested: false,
  }
}

///|
/// Add a node before spinning the executor.
pub fn Executor::add_node(
  self : Executor,
  node : RosNode,
) -> Result[Unit, String] {
  if self.running {
    return Err("cannot add a ROS node while the executor is spinning")
  }
  if self.shutdown_requested {
    return Err("cannot add a ROS node after the executor was shut down")
  }
  if node.executor_attached {
    return Err("a ROS node can only belong to one executor")
  }
  let participant_guid = node.participant.participant().participant_guid()
  for existing in self.nodes {
    if existing.participant.participant().participant_guid() == participant_guid {
      return Err("the ROS node is already attached to this executor")
    }
  }
  node.executor_attached = true
  self.nodes.push(node)
  Ok(())
}

///|
/// Request a running executor to stop.
pub fn Executor::shutdown(self : Executor) -> Unit {
  if self.shutdown_requested {
    return
  }
  self.shutdown_requested = true
  if !self.running {
    self.detach_nodes()
  }
  ignore(self.shutdown_queue.try_put(())) catch {
    _ => ()
  }
}

///|
/// Release nodes after the executor has stopped.
fn Executor::detach_nodes(self : Executor) -> Unit {
  for node in self.nodes {
    node.executor_attached = false
  }
}

///|
/// Wait for input and execute callbacks until shutdown is requested.
pub async fn Executor::spin(self : Executor) -> Result[Unit, String] {
  if self.running {
    return Err("the ROS executor is already spinning")
  }
  if self.shutdown_requested {
    return Ok(())
  }
  if self.nodes.length() == 0 {
    return Err("cannot spin an executor with no ROS nodes")
  }
  self.running = true
  let result = @async.handle_cancellation(async fn() {
    let result = @async.with_task_group() <| group => {
      for node in self.nodes {
        group.spawn_bg(no_wait=true) <| () => {
          match node.participant.announce_spdp_forever(1000) {
            Ok(_) => ()
            Err(message) => fail(message)
          }
        }
        group.spawn_bg(no_wait=true) <| () => {
          let heartbeat_timer = @async.Timer(1000)
          while !self.shutdown_requested {
            heartbeat_timer.wait()
            heartbeat_timer.refresh()
            match node.participant.send_ros_discovery_heartbeats() {
              Ok(_) => ()
              Err(message) => fail(message)
            }
          }
        }
      }
      self.spin_loop()
    }
    self.running = false
    result
  }) catch {
    _ => {
      self.running = false
      self.detach_nodes()
      return Err("a ROS executor task failed")
    }
  }
  self.running = false
  self.detach_nodes()
  match result {
    Some(value) => value
    None => Ok(())
  }
}

///|
async fn Executor::spin_loop(self : Executor) -> Result[Unit, String] {
  while !self.shutdown_requested {
    let tasks : Array[async () -> RosExecutorEvent] = []
    tasks.push(async fn() {
      self.shutdown_queue.get()
      Shutdown
    })
    for node_index in 0..<self.nodes.length() {
      let node = self.nodes[node_index]
      tasks.push(async fn() {
        Discovery(node_index, node.participant.receive_discovery_once())
      })
      tasks.push(async fn() {
        Datagram(node_index, node.participant.user_socket().receive_message())
      })
      for timer_index in 0..<node.timers.length() {
        let timer = node.timers[timer_index].timer
        tasks.push(async fn() {
          timer.wait()
          Timer(node_index, timer_index)
        })
      }
    }
    match @async.any(tasks, allow_failure=true) {
      Shutdown => return Ok(())
      Discovery(node_index, result) =>
        match result {
          Ok((_, event)) =>
            match self.nodes[node_index].handle_discovery_event(event) {
              Ok(_) => ()
              Err(message) => return Err(message)
            }
          Err(message) => return Err(message)
        }
      Datagram(node_index, result) =>
        match result {
          Ok((message, source)) =>
            match self.nodes[node_index].handle_message(message, source) {
              Ok(_) => ()
              Err(message) => return Err(message)
            }
          Err(_) => ()
        }
      Timer(node_index, timer_index) => {
        let callback = self.nodes[node_index].timers[timer_index].callback
        callback()
        self.nodes[node_index].timers[timer_index].timer.refresh()
      }
    }
  }
  Ok(())
}

///|
fn RosNode::handle_discovery_event(
  self : RosNode,
  event : @wire.DiscoveryEvent,
) -> Result[Unit, String] {
  match event {
    Publication(publication) => self.add_publication(publication)
    Subscription(subscription) => {
      for publisher in self.publishers {
        if publisher.topic().dds_name() == subscription.topic_name() &&
          publisher.topic().dds_type_name() == subscription.type_name() {
          let qos = match subscription.qos() {
            Ok(value) => value
            Err(_) => continue
          }
          if qos.reliability() != @rtps.RELIABILITY_BEST_EFFORT ||
            qos.durability() != @rtps.DURABILITY_VOLATILE ||
            !ros_endpoint_has_udp_v4_locator(subscription) {
            continue
          }
          match publisher.add_subscription(subscription) {
            Ok(_) => ()
            Err(message) => return Err(message)
          }
        }
      }
      Ok(())
    }
    EndpointRemoved(kind, endpoint_guid) => {
      match kind {
        Publication =>
          for index in 0..<self.subscriptions.length() {
            let retained : Array[RosNodeReader] = []
            for reader in self.subscriptions[index].readers {
              if reader.endpoint_guid != endpoint_guid {
                retained.push(reader)
              }
            }
            self.subscriptions[index].readers = retained
          }
        Subscription =>
          for publisher in self.publishers {
            publisher.remove_subscription(endpoint_guid)
          }
      }
      Ok(())
    }
    ParticipantRemoved(participant_guid) => {
      let prefix = participant_guid.prefix()
      for index in 0..<self.subscriptions.length() {
        let retained : Array[RosNodeReader] = []
        for reader in self.subscriptions[index].readers {
          if reader.endpoint_guid.prefix() != prefix {
            retained.push(reader)
          }
        }
        self.subscriptions[index].readers = retained
      }
      for publisher in self.publishers {
        publisher.remove_subscriptions_from_participant(prefix)
      }
      Ok(())
    }
    Participant(_) => Ok(())
  }
}

///|
/// Whether a discovered writer can be reached over the UDP/IPv4 transport.
fn ros_endpoint_has_udp_v4_locator(endpoint : @rtps.SedpEndpointData) -> Bool {
  let locators = if endpoint.unicast_locators().length() > 0 {
    endpoint.unicast_locators()
  } else {
    endpoint.multicast_locators()
  }
  for locator in locators {
    if locator.kind() == @rtps.LOCATOR_KIND_UDP_V4 {
      return true
    }
  }
  false
}

///|
async fn RosNode::handle_message(
  self : RosNode,
  message : @rtps.Message,
  source : @socket.Addr,
) -> Result[Unit, String] {
  match self.participant.handle_user_message(message, source) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  for subscription_index in 0..<self.subscriptions.length() {
    let callback = self.subscriptions[subscription_index].callback
    let reader_count = self.subscriptions[subscription_index].readers.length()
    for reader_index in 0..<reader_count {
      let payload = match
        self.subscriptions[subscription_index].readers[reader_index].subscription.handle_message(
          message, source,
        ) {
        Ok(value) => value
        Err(_) => continue
      }
      match payload {
        Some(value) =>
          match callback(value) {
            Ok(_) => ()
            Err(message) => return Err(message)
          }
        None => ()
      }
    }
  }
  Ok(())
}
