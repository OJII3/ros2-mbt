///|
async fn discover_subscription(
  participant : @transport.RosParticipant,
  topic : @ros.RosTopic,
) -> Result[Array[@rtps.SedpEndpointData], String] {
  let remote_subscriptions : Array[@rtps.SedpEndpointData] = []
  let mut quiet_periods = 0
  while remote_subscriptions.length() == 0 ||
        participant.ros_discovery_publisher_count() == 0 ||
        quiet_periods < 12 {
    let graph_publisher_count = participant.ros_discovery_publisher_count()
    let received = if remote_subscriptions.length() > 0 &&
      graph_publisher_count > 0 {
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
          Subscription(subscription) => {
            let compatible = match subscription.qos() {
              Ok(qos) => qos.durability() == @rtps.DURABILITY_VOLATILE
              Err(_) => false
            }
            if compatible &&
              subscription.topic_name() == topic.dds_name() &&
              subscription.type_name() == topic.dds_type_name() {
              let mut found = false
              for index in 0..<remote_subscriptions.length() {
                if remote_subscriptions[index].endpoint_guid() ==
                  subscription.endpoint_guid() {
                  remote_subscriptions[index] = subscription
                  found = true
                }
              }
              if !found {
                remote_subscriptions.push(subscription)
              }
            }
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
  if remote_subscriptions.length() > 0 {
    Ok(remote_subscriptions)
  } else {
    Err("discovery ended without a matching subscription")
  }
}

///|
fn wide_string_payload(index : Int) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match
    writer.write_wstring("wide こんにちは 🙂 #" + index.to_string()) {
    Ok(_) => Ok(writer.to_bytes())
    Err(message) => Err(message)
  }
}

///|
async fn publish_reliable(
  participant : @transport.RosParticipant,
  topic : @ros.RosTopic,
  socket : @transport.Udp,
  prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  writer_id : @rtps.EntityId,
  subscriptions : Array[@rtps.SedpEndpointData],
) -> Unit {
  if subscriptions.length() == 0 {
    return
  }
  let publisher = match
    @transport.ReliableRosPublisher::new_for_subscription(
      topic,
      socket,
      prefix,
      vendor_id,
      writer_id,
      subscriptions[0],
      1L,
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  for index in 1..<subscriptions.length() {
    match publisher.add_subscription(subscriptions[index]) {
      Ok(_) => ()
      Err(message) => {
        println(message)
        publisher.close()
        return
      }
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
    group.spawn_bg(no_wait=true) <| () => {
      while true {
        match participant.receive_discovery_once() {
          Ok((_, event)) =>
            match event {
              Subscription(subscription) =>
                if subscription.topic_name() == topic.dds_name() &&
                  subscription.type_name() == topic.dds_type_name() {
                  match publisher.add_subscription(subscription) {
                    Ok(_) => ()
                    Err(message) => println(message)
                  }
                }
              EndpointRemoved(Subscription, endpoint_guid) =>
                publisher.remove_subscription(endpoint_guid)
              _ => ()
            }
          Err(message) => {
            println(message)
            return
          }
        }
      }
    }
    for index in 0..<5 {
      let payload = match wide_string_payload(index) {
        Ok(value) => value
        Err(message) => {
          println(message)
          publisher.close()
          return
        }
      }
      match publisher.publish(payload) {
        Ok(_) => ()
        Err(message) => {
          println(message)
          publisher.close()
          return
        }
      }
      match publisher.send_heartbeat() {
        Ok(_) => ()
        Err(message) => {
          println(message)
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
/// Publish WString samples on `/wide_chatter` after discovering a reader.
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
      0x4D, 0x42, 0x54, 0x52, 0x50, 0x53, 0, 0, 0, 0, 0, 44,
    ]) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let vendor_id = @rtps.VendorId::new(1, 15)
  let topic = match
    @ros.RosTopic::new("/wide_chatter", "example_interfaces", "msg", "WString") {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let writer_id = match @rtps.EntityId::new(b"\x00\x00\x2C", 0x03) {
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
      44U,
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
  match participant.set_ros_node_identity("/demo", "moon_wstring_talker") {
    Ok(_) => ()
    Err(message) => {
      println(message)
      participant.close()
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
    participant.register_topic_endpoint_with_type_hash(
      topic,
      Publication,
      writer_id,
      qos,
      "RIHS01_32033e06d9dfe5468c5d6e1dc8b7a23c8910bad071cfd4e151a951d580e68dd8",
    ) {
    Ok(_) => ()
    Err(message) => {
      println(message)
      participant.close()
      return
    }
  }
  let subscription = @async.with_task_group() <| group => {
    group.spawn_bg(no_wait=true) <| () => {
      match participant.announce_spdp_forever(1000) {
        Ok(_) => ()
        Err(message) => fail(message)
      }
    }
    discover_subscription(participant, topic)
  }
  let subscriptions = match subscription {
    Ok(value) => value
    Err(message) => {
      println(message)
      participant.close()
      return
    }
  }
  let graph_info = match
    participant.participant_entities_info("/demo", "moon_wstring_talker") {
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
  publish_reliable(
    participant,
    topic,
    participant.user_socket(),
    prefix,
    vendor_id,
    writer_id,
    subscriptions,
  )
  participant.close_discovery()
}
