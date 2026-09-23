///|
async fn publish_reliable(
  participant : @transport.RosParticipant,
  topic : @ros.RosTopic,
  socket : @transport.Udp,
  prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  writer_id : @rtps.EntityId,
) -> Unit {
  let publisher = match
    @transport.ReliableRosPublisher::new(
      topic, socket, prefix, vendor_id, writer_id, 1L,
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  @async.with_task_group() <| group => {
    group.spawn_bg(no_wait=true) <| () => {
      match participant.announce_spdp_forever(1000) {
        Ok(_) => ()
        Err(message) => fail(message)
      }
    }
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
              ParticipantRemoved(participant_guid) =>
                publisher.remove_subscriptions_from_participant(
                  participant_guid.prefix(),
                )
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
/// Publish String samples on `/chatter` without waiting for a subscription.
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
  let writer_id = match @rtps.EntityId::new(b"\x00\x00\x2A", 0x03) {
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
      42U,
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
  match participant.set_ros_node_identity("/demo", "moon_talker") {
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
      @ros.STD_MSGS_STRING_TYPE_HASH,
    ) {
    Ok(_) => ()
    Err(message) => {
      println(message)
      participant.close()
      return
    }
  }
  publish_reliable(
    participant,
    topic,
    participant.user_socket(),
    prefix,
    vendor_id,
    writer_id,
  )
  participant.close_discovery()
}
