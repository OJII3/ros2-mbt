///|
const CLI_PARTICIPANT_ID : UInt = 90U

///|
const CLI_DISCOVERY_INTERVAL_MS : Int = 1000

///|
const CLI_DISCOVERY_POLL_MS : Int = 100

///|
struct CliParticipant {
  participant : @transport.RosParticipant
  prefix : @rtps.GuidPrefix
  vendor_id : @rtps.VendorId
}

///|
async fn new_cli_participant(
  register_graph : Bool,
) -> Result[CliParticipant, String] {
  let config = match @config.load() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let prefix = match
    @rtps.GuidPrefix::from_array([
      0x4D, 0x42, 0x54, 0x52, 0x50, 0x53, 0, 0, 0, 0, 0, 90,
    ]) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let vendor_id = @rtps.VendorId::new(1, 15)
  let participant = match
    @transport.RosParticipant::new_ddsi(
      prefix,
      vendor_id,
      config.domain_id,
      CLI_PARTICIPANT_ID,
      config.ip,
      60,
      1L,
      multicast_interface?=config.multicast_interface,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if register_graph {
    let publication_id = match
      @rtps.EntityId::new(b"gph", @ros.ROS_GRAPH_PUBLICATION_ENTITY_KIND) {
      Ok(value) => value
      Err(message) => {
        participant.close()
        return Err(message)
      }
    }
    let subscription_id = match
      @rtps.EntityId::new(b"gph", @ros.ROS_GRAPH_SUBSCRIPTION_ENTITY_KIND) {
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
  }
  Ok({ participant, prefix, vendor_id, })
}

///|
async fn receive_graph_samples(
  participant : @transport.RosParticipant,
) -> Result[Unit, String] {
  let subscription_count = participant.ros_discovery_subscription_count()
  for index in 0..<subscription_count {
    match
      @async.with_timeout_opt(5, async fn() {
        participant.receive_ros_discovery_info(index)
      }) {
      None => ()
      Some(Ok(_)) => ()
      Some(Err(message)) => return Err(message)
    }
  }
  Ok(())
}

///|
/// Process discovery traffic for a bounded amount of time.
async fn spin_discovery(
  participant : @transport.RosParticipant,
  duration_ms : Int,
  collect_graph : Bool,
) -> Result[Unit, String] {
  if duration_ms <= 0 {
    return Err("the discovery spin time must be positive")
  }
  let deadline = @async.now() + duration_ms.to_int64()
  while true {
    let remaining_ms = (deadline - @async.now()).to_int()
    if remaining_ms <= 0 {
      return Ok(())
    }
    let timeout_ms = if remaining_ms < CLI_DISCOVERY_POLL_MS {
      remaining_ms
    } else {
      CLI_DISCOVERY_POLL_MS
    }
    match
      @async.with_timeout_opt(timeout_ms, async fn() {
        participant.receive_discovery_once()
      }) {
      None => ()
      Some(Ok(_)) => ()
      Some(Err(message)) => return Err(message)
    }
    if collect_graph {
      match receive_graph_samples(participant) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    }
  } nobreak {
    Err("discovery loop stopped")
  }
}

///|
fn normalize_ros_topic_name(name : String) -> Result[String, String] {
  if name.length() == 0 {
    return Err("topic name must not be empty")
  }
  if name[0] == '/' {
    Ok(name)
  } else {
    Ok("/" + name)
  }
}

///|
fn find_publication(
  participant : @transport.RosParticipant,
  ros_name : String,
) -> Result[@rtps.SedpEndpointData, String] {
  let dds_name = match @ros.ros_topic_to_dds(ros_name) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  for publication in participant.graph().publications() {
    if publication.topic_name() == dds_name {
      return Ok(publication)
    }
  }
  Err("no publication was discovered for " + ros_name)
}
