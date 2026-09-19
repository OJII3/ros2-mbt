///|
/// Receive a small number of reliable String samples after discovering a ROS 2
/// publication on `/chatter`.
async fn main {
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
  let reader_id = match @rtps.EntityId::new(b"\x00\x00\x2B", 0xC7) {
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
      prefix, vendor_id, 0U, 43U, 0x7F000001U, 60, 1L,
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
      @rtps.SedpEndpointKind::Subscription,
      reader_id,
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
    participant.participant_entities_info("/demo", "moon_listener") {
    Ok(value) => value
    Err(message) => {
      println(message)
      participant.close()
      return
    }
  }
  match participant.announce_spdp_once() {
    Ok(_) => ()
    Err(message) => {
      println(message)
      participant.close()
      return
    }
  }
  let mut remote_publication : @rtps.SedpEndpointData? = None
  let mut graph_info_published = false
  while remote_publication is None {
    match participant.receive_discovery_once_with_spdp(1000) {
      Ok((_, @transport.DiscoveryEvent::Publication(publication))) =>
        if publication.topic_name() == topic.dds_name() &&
          publication.type_name() == topic.dds_type_name() {
          remote_publication = Some(publication)
        }
      Ok(_) => ()
      Err(message) => {
        println(message)
        participant.close()
        return
      }
    }
    if !graph_info_published && participant.ros_discovery_publisher_count() > 0 {
      match participant.publish_ros_discovery_info(graph_info) {
        Ok(_) => graph_info_published = true
        Err(message) => {
          println(message)
          participant.close()
          return
        }
      }
    }
  }
  if !graph_info_published && participant.ros_discovery_publisher_count() > 0 {
    match participant.publish_ros_discovery_info(graph_info) {
      Ok(_) => graph_info_published = true
      Err(message) => {
        println(message)
        participant.close()
        return
      }
    }
  }
  let publication = match remote_publication {
    Some(value) => value
    None => return
  }
  let (discovery, user_socket) = participant.into_parts()
  discovery.close()
  let subscription = match
    @transport.ReliableRosSubscription::new_for_publication(
      topic, user_socket, prefix, vendor_id, reader_id, publication,
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
