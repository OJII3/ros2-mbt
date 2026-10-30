///|
priv struct BagPlaybackPublisher {
  topic_name : String
  publisher : @transport.RosNodePublisher[Bytes]
}

///|
fn parse_rate_milli(value : String) -> Result[UInt32, String] {
  let parts = value.split(".").collect()
  if parts.length() > 2 {
    return Err("option --rate must be a positive decimal number")
  }
  let whole = if parts[0].length() == 0 {
    0
  } else {
    @string.parse_int(parts[0]) catch {
      _ => return Err("option --rate must be a positive decimal number")
    }
  }
  let fractional_text = if parts.length() == 2 { parts[1] } else { "" }
  if fractional_text.length() > 3 {
    return Err("option --rate supports at most three decimal places")
  }
  let fractional = if fractional_text.length() == 0 {
    0
  } else {
    @string.parse_int(fractional_text) catch {
      _ => return Err("option --rate must be a positive decimal number")
    }
  }
  if whole < 0 || fractional < 0 || whole > 2_147_483 {
    return Err("option --rate must be a positive decimal number")
  }
  let fractional_milli = match fractional_text.length() {
    0 => 0
    1 => fractional * 100
    2 => fractional * 10
    _ => fractional
  }
  let rate_milli = whole * 1000 + fractional_milli
  if rate_milli <= 0 || rate_milli > 2_147_483_647 {
    return Err("option --rate must be positive and within the supported range")
  }
  Ok(rate_milli.reinterpret_as_uint())
}

///|
async fn scan_bag_file(path : String) -> Result[@rosbag.BagCatalog, String] {
  let file = @fs.open(path, mode=ReadOnly) catch {
    _ => return Err("could not open MCAP file: " + path)
  }
  defer file.close()
  let reader = match @mcap.Reader::new(file) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  @rosbag.scan_mcap_catalog(reader)
}

///|
fn topic_ros_descriptor(
  topic : @rosbag.BagTopic,
) -> Result[@ros.RosTopic, String] {
  let parts = topic.type_name().split("/").collect()
  if parts.length() != 3 || parts[1] != "msg" {
    return Err("unsupported ROS topic type: " + topic.type_name())
  }
  @ros.RosTopic::new(
    topic.name(),
    parts[0].to_owned(),
    parts[1].to_owned(),
    parts[2].to_owned(),
  )
}

///|
async fn create_bag_publishers(
  node : @transport.RosNode,
  topics : Array[@rosbag.BagTopic],
) -> Result[Array[BagPlaybackPublisher], String] {
  let publishers : Array[BagPlaybackPublisher] = []
  for topic in topics {
    for qos_profile in topic.qos_profiles() {
      if qos_profile_uses_transient_local(qos_profile) {
        return Err(
          "topic " +
          topic.name() +
          " uses transient_local durability, which the publisher transport does not support",
        )
      }
    }
    let ros_topic = match topic_ros_descriptor(topic) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let publisher = match
      node.create_publisher(ros_topic, topic.type_hash(), fn(payload : Bytes) {
        Ok(payload)
      }) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    publishers.push({ topic_name: topic.name(), publisher, })
  }
  Ok(publishers)
}

///|
fn qos_profile_uses_transient_local(profile : String) -> Bool {
  profile.contains("transient_local") ||
  profile.contains("TRANSIENT_LOCAL") ||
  profile.contains("durability: 1")
}

///|
async fn publish_bag_message(
  publishers : Array[BagPlaybackPublisher],
  topic_name : String,
  payload : Bytes,
) -> Result[Unit, String] {
  for target in publishers {
    if target.topic_name == topic_name {
      return target.publisher.publish_without_heartbeat(payload)
    }
  }
  Err("no publisher was created for bag topic: " + topic_name)
}

///|
async fn play_bag_pass(
  path : String,
  catalog : @rosbag.BagCatalog,
  topic_names : Array[String],
  rate_milli : UInt32,
  publishers : Array[BagPlaybackPublisher],
) -> Result[UInt64, String] {
  let file = @fs.open(path, mode=ReadOnly) catch {
    _ => return Err("could not reopen MCAP file for playback: " + path)
  }
  defer file.close()
  let reader = match @mcap.Reader::new(file) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let source = match @rosbag.McapMessageSource::new(reader, catalog) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  @rosbag.play(
    source,
    topic_names,
    rate_milli,
    fn() { @async.now() },
    async fn(duration_ms) { @async.sleep(duration_ms) },
    async fn(topic_name, payload) {
      publish_bag_message(publishers, topic_name, payload)
    },
  )
}

///|
/// Play a ROS 2 MCAP file through the native ROS node transport.
async fn run_bag_play(
  path : String,
  requested_topics : Array[String],
  rate_milli : UInt32,
  discovery_time_ms : Int32,
  loop_enabled : Bool,
) -> Result[Unit, String] {
  let catalog = match scan_bag_file(path) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let selected_topics = match catalog.select_topics(requested_topics) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let config = match @config.load() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let node = match
    @transport.RosNode::new_ddsi(
      "/ros2_mbt",
      "bag_player",
      domain_id=config.domain_id,
      participant_id=91U,
      ip=config.ip,
      multicast_interface?=config.multicast_interface,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let publishers = match create_bag_publishers(node, selected_topics) {
    Ok(value) => value
    Err(message) => {
      ignore(node.dispose_and_close())
      return Err(message)
    }
  }
  let executor = @transport.Executor::new()
  match executor.add_node(node) {
    Ok(_) => ()
    Err(message) => {
      ignore(node.dispose_and_close())
      return Err(message)
    }
  }
  let topic_names : Array[String] = []
  for topic in selected_topics {
    topic_names.push(topic.name())
  }
  let playback_result = try
    @async.with_task_group() <| group => {
      group.spawn_bg(no_wait=true) <| () => {
        match executor.spin() {
          Ok(_) => ()
          Err(message) => fail(message)
        }
      }
      defer executor.shutdown()
      @async.sleep(discovery_time_ms)
      if loop_enabled {
        println("looping playback; press Ctrl-C to stop")
      }
      @rosbag.play_repeatedly(loop_enabled, async fn() {
        play_bag_pass(path, catalog, topic_names, rate_milli, publishers)
      })
    }
  catch {
    _ => Err("ROS executor failed while playing the MCAP file")
  }
  executor.shutdown()
  let dispose_result = node.dispose_and_close()
  match playback_result {
    Err(message) => {
      ignore(dispose_result)
      Err(message)
    }
    Ok(message_count) =>
      match dispose_result {
        Ok(_) => {
          println("played " + message_count.to_string() + " messages")
          Ok(())
        }
        Err(message) => Err(message)
      }
  }
}
