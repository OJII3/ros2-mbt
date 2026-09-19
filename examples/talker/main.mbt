///|
/// Discover the remote subscription and publish the local graph information.
async fn discover_subscription(
  participant : @transport.RosParticipant,
  topic : @ros.RosTopic,
  graph_info : @ros.ParticipantEntitiesInfo,
) -> Result[@rtps.SedpEndpointData, String] {
  let mut remote_subscription : @rtps.SedpEndpointData? = None
  let mut graph_info_published = false
  while remote_subscription is None {
    match participant.receive_discovery_once() {
      Ok((_, @transport.DiscoveryEvent::Subscription(subscription))) =>
        if subscription.topic_name() == topic.dds_name() &&
          subscription.type_name() == topic.dds_type_name() {
          remote_subscription = Some(subscription)
        }
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    if !graph_info_published && participant.ros_discovery_publisher_count() > 0 {
      match participant.publish_ros_discovery_info(graph_info) {
        Ok(_) => graph_info_published = true
        Err(message) => return Err(message)
      }
    }
  }
  if !graph_info_published && participant.ros_discovery_publisher_count() > 0 {
    match participant.publish_ros_discovery_info(graph_info) {
      Ok(_) => graph_info_published = true
      Err(message) => return Err(message)
    }
  }
  match remote_subscription {
    Some(value) => Ok(value)
    None => Err("discovery ended without a matching subscription")
  }
}

///|
async fn publish_reliable(
  topic : @ros.RosTopic,
  socket : @transport.Udp,
  prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  writer_id : @rtps.EntityId,
  subscription : @rtps.SedpEndpointData,
) -> Unit {
  let publisher = match
    @transport.ReliableRosPublisher::new_for_subscription(
      topic, socket, prefix, vendor_id, writer_id, subscription, 1L,
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  @async.with_task_group() <| group => {
    group.spawn_bg(no_wait=true) <| () => {
      while true {
        match publisher.receive_control() {
          Ok(_) => ()
          Err(_) => return
        }
      }
    }
    for index in 0..<5 {
      let message = @ros.StringMessage::new(
        "hello from MoonBit #" + index.to_string(),
      )
      match publisher.publish(message.to_cdr_bytes()) {
        Ok(_) => ()
        Err(error) => {
          println(error)
          publisher.close()
          return
        }
      }
      match publisher.send_heartbeat() {
        Ok(_) => ()
        Err(error) => {
          println(error)
          publisher.close()
          return
        }
      }
      @async.sleep(1000)
    }
  }
  publisher.close()
}

///|
async fn publish_best_effort(
  topic : @ros.RosTopic,
  socket : @transport.Udp,
  prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  writer_id : @rtps.EntityId,
  subscription : @rtps.SedpEndpointData,
) -> Unit {
  let publisher = match
    @transport.RosPublisher::new_for_subscription(
      topic, socket, prefix, vendor_id, writer_id, subscription, 1L,
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  for index in 0..<5 {
    let message = @ros.StringMessage::new(
      "hello from MoonBit #" + index.to_string(),
    )
    match publisher.publish(message.to_cdr_bytes()) {
      Ok(_) => ()
      Err(error) => {
        println(error)
        publisher.close()
        return
      }
    }
    @async.sleep(1000)
  }
  publisher.close()
}

///|
/// Publish String samples after discovering a ROS 2 subscription on `/chatter`.
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
      0x4D, 0x42, 0x54, 0x52, 0x50, 0x53, 0, 0, 0, 0, 0, 42,
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
  let writer_id = match @rtps.EntityId::new(b"\x00\x00\x2A", 0xC2) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let graph_publication_id = match @rtps.EntityId::new(b"gph", 0xC2) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let graph_subscription_id = match @rtps.EntityId::new(b"gph", 0xC7) {
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
      42U,
      config.ip,
      60,
      1L,
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let qos = @rtps.SedpQos::new(
    @rtps.RELIABILITY_RELIABLE,
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
    participant.register_topic_endpoint(
      topic,
      @rtps.SedpEndpointKind::Publication,
      writer_id,
      qos,
    ) {
    Ok(_) => ()
    Err(message) => {
      println(message)
      participant.close()
      return
    }
  }
  let graph_info = match
    participant.participant_entities_info("/demo", "moon_talker") {
    Ok(value) => value
    Err(message) => {
      println(message)
      participant.close()
      return
    }
  }
  let discovered_subscription = @async.with_task_group() <| group => {
    group.spawn_bg(no_wait=true) <| () => {
      match participant.announce_spdp_forever(1000) {
        Ok(_) => ()
        Err(message) => fail(message)
      }
    }
    discover_subscription(participant, topic, graph_info)
  }
  let subscription = match discovered_subscription {
    Ok(value) => value
    Err(message) => {
      println(message)
      participant.close()
      return
    }
  }
  let is_reliable = match subscription.qos() {
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
    publish_reliable(
      topic, user_socket, prefix, vendor_id, writer_id, subscription,
    )
  } else {
    publish_best_effort(
      topic, user_socket, prefix, vendor_id, writer_id, subscription,
    )
  }
}
