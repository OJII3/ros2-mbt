///|
/// A lightweight ROS node that groups topic entities and callbacks.
pub struct RosNode {
  priv participant : RosParticipant
  priv subscriptions : Array[RosNodeSubscription]
  priv publishers : Array[RosNodePublisherEntry]
  priv timers : Array[RosNodeTimer]
  priv mut next_entity_key : UInt32
  priv mut executor_attached : Bool
}

///|
priv enum RosNodeReaderKind {
  BestEffort(RosSubscription)
  Reliable(ReliableRosSubscription)
}

///|
priv struct RosNodeReader {
  endpoint_guid : @rtps.Guid
  reader : RosNodeReaderKind
}

///|
priv struct RosNodeSubscription {
  topic : @ros_types.RosTopic
  reader_id : @rtps.EntityId
  qos : @rtps.SedpQos
  callback : async (Bytes) -> Result[Unit, String]
  mut readers : Array[RosNodeReader]
}

///|
priv struct RosNodePublisherEntry {
  publisher : ReliableRosPublisher
  qos : @rtps.SedpQos
}

///|
priv struct RosNodeTimer {
  timer : @async.Timer
  callback : async () -> Unit
}

///|
/// A publisher returned by `RosNode::create_publisher`.
pub struct RosNodePublisher[T] {
  priv publisher : ReliableRosPublisher
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
/// Create a ROS topic publisher.
///
/// The encoder converts a message value to its serialized CDR payload.
pub async fn[T] RosNode::create_publisher(
  self : RosNode,
  topic : @ros_types.RosTopic,
  type_hash : String,
  encoder : (T) -> Result[Bytes, String],
  qos~ : @rtps.SedpQos = @rtps.SedpQos::reliable(),
) -> Result[RosNodePublisher[T], String] {
  if qos.durability() != @rtps.DURABILITY_VOLATILE {
    return Err("only volatile durability is supported for user topics")
  }
  let writer_id = match self.next_entity_id(0x03) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let publisher = match
    ReliableRosPublisher::new(
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
  self.publishers.push({ publisher, qos, })
  let publisher_index = self.publishers.length() - 1
  let graph = self.participant.graph()
  for subscription in graph.subscriptions() {
    if subscription.topic_name() == topic.dds_name() &&
      subscription.type_name() == topic.dds_type_name() {
      let sub_qos = match subscription.qos() {
        Ok(value) => value
        Err(_) => continue
      }
      if !qos.compatible_with(sub_qos) ||
        sub_qos.durability() != @rtps.DURABILITY_VOLATILE ||
        !ros_endpoint_has_udp_v4_locator(subscription) {
        continue
      }
      match
        self.publishers[publisher_index].publisher.add_subscription(
          subscription,
        ) {
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
  match self.publisher.publish(payload) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  self.publisher.send_heartbeat()
}

///|
/// Create a subscription with a typed message callback.
///
/// The decoder converts the serialized CDR payload to a message value.
pub async fn[T] RosNode::create_subscription(
  self : RosNode,
  topic : @ros_types.RosTopic,
  type_hash : String,
  decoder : (Bytes) -> Result[T, String],
  callback : async (T) -> Unit,
  qos~ : @rtps.SedpQos = @rtps.SedpQos::reliable(),
) -> Result[Unit, String] {
  if qos.durability() != @rtps.DURABILITY_VOLATILE {
    return Err("only volatile durability is supported for user topics")
  }
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
    qos,
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
    let pub_qos = match publication.qos() {
      Ok(value) => value
      Err(_) => continue
    }
    if !pub_qos.compatible_with(subscription.qos) ||
      !ros_endpoint_has_udp_v4_locator(publication) {
      continue
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
    let reader_kind = if subscription.qos.reliability() ==
      @rtps.RELIABILITY_RELIABLE {
      let reader = match
        ReliableRosSubscription::new_for_publication(
          subscription.topic,
          self.participant.user_socket(),
          self.participant.participant().participant_guid().prefix(),
          self.participant.participant().vendor_id(),
          subscription.reader_id,
          publication,
        ) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      Reliable(reader)
    } else {
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
      BestEffort(reader)
    }
    self.subscriptions[index].readers.push({
      endpoint_guid,
      reader: reader_kind,
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
/// Send heartbeat announcements from all reliable publishers.
pub async fn RosNode::send_publisher_heartbeats(
  self : RosNode,
) -> Result[Unit, String] {
  for entry in self.publishers {
    match entry.publisher.send_heartbeat() {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
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
/// Executor-facing view of a node's event sources and event handlers.
priv struct RosNodeExecutorInterface {
  node : RosNode
}

///|
fn RosNode::executor_interface(self : RosNode) -> RosNodeExecutorInterface {
  { node: self, }
}

///|
fn RosNodeExecutorInterface::participant_guid(
  self : RosNodeExecutorInterface,
) -> @rtps.Guid {
  self.node.participant.participant().participant_guid()
}

///|
fn RosNodeExecutorInterface::is_attached(
  self : RosNodeExecutorInterface,
) -> Bool {
  self.node.executor_attached
}

///|
fn RosNodeExecutorInterface::attach(self : RosNodeExecutorInterface) -> Unit {
  self.node.executor_attached = true
}

///|
fn RosNodeExecutorInterface::detach(self : RosNodeExecutorInterface) -> Unit {
  self.node.executor_attached = false
}

///|
async fn RosNodeExecutorInterface::announce_spdp_forever(
  self : RosNodeExecutorInterface,
  period_ms : Int32,
) -> Result[Unit, String] {
  self.node.participant.announce_spdp_forever(period_ms)
}

///|
async fn RosNodeExecutorInterface::send_heartbeats(
  self : RosNodeExecutorInterface,
) -> Result[Unit, String] {
  match self.node.participant.send_ros_discovery_heartbeats() {
    Ok(_) => self.node.send_publisher_heartbeats()
    Err(message) => Err(message)
  }
}

///|
async fn RosNodeExecutorInterface::receive_discovery(
  self : RosNodeExecutorInterface,
) -> Result[(@socket.Addr, @wire.DiscoveryEvent), String] {
  self.node.participant.receive_discovery_once()
}

///|
async fn RosNodeExecutorInterface::receive_datagram(
  self : RosNodeExecutorInterface,
) -> Result[(@rtps.Message, @socket.Addr), String] {
  self.node.participant.user_socket().receive_message()
}

///|
fn RosNodeExecutorInterface::timer_count(
  self : RosNodeExecutorInterface,
) -> Int32 {
  self.node.timers.length()
}

///|
async fn RosNodeExecutorInterface::wait_timer(
  self : RosNodeExecutorInterface,
  timer_index : Int32,
) -> Unit {
  self.node.timers[timer_index].timer.wait()
}

///|
async fn RosNodeExecutorInterface::run_timer(
  self : RosNodeExecutorInterface,
  timer_index : Int32,
) -> Unit {
  let callback = self.node.timers[timer_index].callback
  callback()
  self.node.timers[timer_index].timer.refresh()
}

///|
fn RosNodeExecutorInterface::handle_discovery_event(
  self : RosNodeExecutorInterface,
  event : @wire.DiscoveryEvent,
) -> Result[Unit, String] {
  self.node.handle_discovery_event(event)
}

///|
async fn RosNodeExecutorInterface::handle_message(
  self : RosNodeExecutorInterface,
  message : @rtps.Message,
  source : @socket.Addr,
) -> Result[Unit, String] {
  self.node.handle_message(message, source)
}

///|
/// Drive ROS node discovery, best-effort topic traffic, timers, and callbacks.
pub struct Executor {
  priv nodes : Array[RosNodeExecutorInterface]
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
  let node_interface = node.executor_interface()
  if node_interface.is_attached() {
    return Err("a ROS node can only belong to one executor")
  }
  for existing in self.nodes {
    if existing.participant_guid() == node_interface.participant_guid() {
      return Err("the ROS node is already attached to this executor")
    }
  }
  node_interface.attach()
  self.nodes.push(node_interface)
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
    node.detach()
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
          match node.announce_spdp_forever(1000) {
            Ok(_) => ()
            Err(message) => fail(message)
          }
        }
        group.spawn_bg(no_wait=true) <| () => {
          let heartbeat_timer = @async.Timer(1000)
          while !self.shutdown_requested {
            heartbeat_timer.wait()
            heartbeat_timer.refresh()
            match node.send_heartbeats() {
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
    Failure(message) => {
      self.running = false
      self.detach_nodes()
      return Err(message)
    }
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
      tasks.push(async fn() { Discovery(node_index, node.receive_discovery()) })
      tasks.push(async fn() { Datagram(node_index, node.receive_datagram()) })
      for timer_index in 0..<node.timer_count() {
        tasks.push(async fn() {
          node.wait_timer(timer_index)
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
      Timer(node_index, timer_index) =>
        self.nodes[node_index].run_timer(timer_index)
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
      for entry in self.publishers {
        if entry.publisher.topic().dds_name() == subscription.topic_name() &&
          entry.publisher.topic().dds_type_name() == subscription.type_name() {
          let sub_qos = match subscription.qos() {
            Ok(value) => value
            Err(_) => continue
          }
          if !entry.qos.compatible_with(sub_qos) ||
            sub_qos.durability() != @rtps.DURABILITY_VOLATILE ||
            !ros_endpoint_has_udp_v4_locator(subscription) {
            continue
          }
          match entry.publisher.add_subscription(subscription) {
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
          for entry in self.publishers {
            entry.publisher.remove_subscription(endpoint_guid)
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
      for entry in self.publishers {
        entry.publisher.remove_subscriptions_from_participant(prefix)
      }
      Ok(())
    }
    Participant(_) => Ok(())
  }
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
  for entry in self.publishers {
    match entry.publisher.handle_message(message) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  for subscription_index in 0..<self.subscriptions.length() {
    let callback = self.subscriptions[subscription_index].callback
    let reader_count = self.subscriptions[subscription_index].readers.length()
    for reader_index in 0..<reader_count {
      let reader = self.subscriptions[subscription_index].readers[reader_index]
      match reader.reader {
        BestEffort(sub) => {
          let payload = match sub.handle_message(message, source) {
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
        Reliable(sub) => {
          let payloads = match sub.handle_message(message, source) {
            Ok(value) => value
            Err(_) => continue
          }
          for payload in payloads {
            match callback(payload) {
              Ok(_) => ()
              Err(message) => return Err(message)
            }
          }
        }
      }
    }
  }
  Ok(())
}
