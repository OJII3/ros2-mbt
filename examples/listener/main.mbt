///|
/// Discover the remote publication.
async fn discover_publication(
  participant : @transport.RosParticipant,
  topic : @ros.RosTopic,
) -> Result[@rtps.SedpEndpointData, String] {
  let mut remote_publication : @rtps.SedpEndpointData? = None
  let mut quiet_periods = 0
  // Other ROS graph readers can arrive after the first matching endpoints.
  while remote_publication is None ||
        participant.ros_discovery_publisher_count() == 0 ||
        quiet_periods < 12 {
    let graph_publisher_count = participant.ros_discovery_publisher_count()
    let received = if remote_publication is Some(_) && graph_publisher_count > 0 {
      @async.with_timeout_opt(250, async fn() {
        participant.receive_discovery_once()
      })
    } else {
      Some(participant.receive_discovery_once())
    }
    match received {
      None => quiet_periods += 1
      Some(Ok((_, event))) => {
        match event {
          Publication(publication) =>
            if publication.topic_name() == topic.dds_name() &&
              publication.type_name() == topic.dds_type_name() {
              remote_publication = Some(publication)
            }
          _ => ()
        }
        if participant.ros_discovery_publisher_count() > graph_publisher_count {
          quiet_periods = 0
        }
      }
      Some(Err(message)) => return Err(message)
    }
  }
  match remote_publication {
    Some(value) => Ok(value)
    None => Err("discovery ended without a matching publication")
  }
}

///|
async fn receive_reliable(
  topic : @ros.RosTopic,
  socket : @transport.Udp,
  prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  reader_id : @rtps.EntityId,
  publication : @rtps.SedpEndpointData,
) -> Unit {
  let subscription = match
    @transport.ReliableRosSubscription::new_for_publication(
      topic, socket, prefix, vendor_id, reader_id, publication,
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  for _ in 0..<5 {
    let (payload, _) = match subscription.receive() {
      Ok(value) => value
      Err(error) => {
        println(error)
        subscription.close()
        return
      }
    }
    let message = match @ros.StringMessage::from_cdr_bytes(payload) {
      Ok(value) => value
      Err(error) => {
        println(error)
        subscription.close()
        return
      }
    }
    println(message.data())
  }
  subscription.close()
}

///|
async fn receive_best_effort(
  topic : @ros.RosTopic,
  socket : @transport.Udp,
  prefix : @rtps.GuidPrefix,
  reader_id : @rtps.EntityId,
  publication : @rtps.SedpEndpointData,
) -> Unit {
  let subscription = match
    @transport.RosSubscription::new_for_publication_with_prefix(
      topic, socket, prefix, reader_id, publication,
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  for _ in 0..<5 {
    let (payload, _) = match subscription.receive() {
      Ok(value) => value
      Err(error) => {
        println(error)
        subscription.close()
        return
      }
    }
    let message = match @ros.StringMessage::from_cdr_bytes(payload) {
      Ok(value) => value
      Err(error) => {
        println(error)
        subscription.close()
        return
      }
    }
    println(message.data())
  }
  subscription.close()
}

///|
/// Receive String samples after discovering a ROS 2 publication on `/chatter`.
async fn main {
  let config = match @config.load() {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let prefix = match
    @rtps.GuidPrefix::from_array([
      0x4D, 0x42, 0x54, 0x52, 0x50, 0x53, 0, 0, 0, 0, 0, 43,
    ]) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let vendor_id = @rtps.VendorId::new(1, 15)
  let topic = match
    @ros.RosTopic::new("/chatter", "std_msgs", "msg", "String") {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let reader_id = match @rtps.EntityId::new(b"\x00\x00\x2B", 0x04) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let graph_publication_id = match
    @rtps.EntityId::new(b"gph", @ros.ROS_GRAPH_PUBLICATION_ENTITY_KIND) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let graph_subscription_id = match
    @rtps.EntityId::new(b"gph", @ros.ROS_GRAPH_SUBSCRIPTION_ENTITY_KIND) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let participant = match
    @transport.RosParticipant::new_ddsi(
      prefix,
      vendor_id,
      config.domain_id,
      43U,
      config.ip,
      60,
      1L,
      multicast_interface?=config.multicast_interface,
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  match participant.set_ros_node_identity("/demo", "moon_listener") {
    Ok(_) => ()
    Err(message) => {
      println(message)
      participant.close()
      return
    }
  }
  let qos = @rtps.SedpQos::new(
    @rtps.RELIABILITY_BEST_EFFORT,
    @rtps.DURABILITY_VOLATILE,
    @rtps.HISTORY_KEEP_LAST,
    10,
  )
  match
    participant.register_ros_discovery_info(
      graph_publication_id, graph_subscription_id,
    ) {
    Ok(_) => ()
    Err(message) => {
      println(message)
      participant.close()
      return
    }
  }
  match
    participant.register_topic_endpoint_with_type_hash(
      topic,
      Subscription,
      reader_id,
      qos,
      @ros.STD_MSGS_STRING_TYPE_HASH,
    ) {
    Ok(_) => ()
    Err(message) => {
      println(message)
      participant.close()
      return
    }
  }
  let discovered_publication = @async.with_task_group() <| group => {
    group.spawn_bg(no_wait=true) <| () => {
      match participant.announce_spdp_forever(1000) {
        Ok(_) => ()
        Err(message) => fail(message)
      }
    }
    discover_publication(participant, topic)
  }
  let publication = match discovered_publication {
    Ok(value) => value
    Err(message) => {
      println(message)
      participant.close()
      return
    }
  }
  let graph_info = match
    participant.participant_entities_info("/demo", "moon_listener") {
    Ok(value) => value
    Err(message) => {
      println(message)
      participant.close()
      return
    }
  }
  for _ in 0..<3 {
    match participant.publish_ros_discovery_info(graph_info) {
      Ok(_) => ()
      Err(message) => {
        println(message)
        participant.close()
        return
      }
    }
    @async.sleep(250)
  }
  let is_reliable = match publication.qos() {
    Ok(qos) => qos.reliability() == @rtps.RELIABILITY_RELIABLE
    Err(message) => {
      println(message)
      participant.close()
      return
    }
  }
  let (discovery, user_socket) = participant.into_parts()
  discovery.close()
  if is_reliable {
    receive_reliable(
      topic, user_socket, prefix, vendor_id, reader_id, publication,
    )
  } else {
    receive_best_effort(topic, user_socket, prefix, reader_id, publication)
  }
}
