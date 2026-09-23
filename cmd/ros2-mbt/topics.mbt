///|
struct TopicSummary {
  ros_name : String
  type_name : String
  mut publishers : Int
  mut subscriptions : Int
}

///|
fn ros_topic_name_from_dds(dds_name : String) -> String? {
  if !dds_name.has_prefix("rt/") || dds_name.length() <= 3 {
    return None
  }
  Some("/" + dds_name[3:].to_owned())
}

///|
fn ros_type_name_from_dds(dds_type_name : String) -> String {
  let parts = dds_type_name.split("::").collect()
  if parts.length() == 4 && parts[2] == "dds_" && parts[3].length() > 1 {
    return parts[0].to_owned() +
      "/" +
      parts[1].to_owned() +
      "/" +
      parts[3][0:parts[3].length() - 1].to_owned()
  }
  dds_type_name
}

///|
fn add_topic_endpoint(
  topics : Array[TopicSummary],
  endpoint : @rtps.SedpEndpointData,
) -> Unit {
  let ros_name = match ros_topic_name_from_dds(endpoint.topic_name()) {
    Some(value) => value
    None => return
  }
  let type_name = ros_type_name_from_dds(endpoint.type_name())
  for topic in topics {
    if topic.ros_name == ros_name && topic.type_name == type_name {
      match endpoint.kind() {
        Publication => topic.publishers += 1
        Subscription => topic.subscriptions += 1
      }
      return
    }
  }
  let summary = { ros_name, type_name, publishers: 0, subscriptions: 0, }
  match endpoint.kind() {
    Publication => summary.publishers = 1
    Subscription => summary.subscriptions = 1
  }
  topics.push(summary)
}

///|
fn topic_summaries(graph : @transport.DiscoveryGraph) -> Array[TopicSummary] {
  let topics : Array[TopicSummary] = []
  for publication in graph.publications() {
    add_topic_endpoint(topics, publication)
  }
  for subscription in graph.subscriptions() {
    add_topic_endpoint(topics, subscription)
  }
  topics.sort_by(fn(left, right) {
    let by_name = left.ros_name.lexical_compare(right.ros_name)
    if by_name == 0 {
      left.type_name.lexical_compare(right.type_name)
    } else {
      by_name
    }
  })
  topics
}

///|
fn print_topic_summaries(topics : Array[TopicSummary]) -> Unit {
  for topic in topics {
    println(
      topic.ros_name +
      " [" +
      topic.type_name +
      "]" +
      " publishers: " +
      topic.publishers.to_string() +
      " subscriptions: " +
      topic.subscriptions.to_string(),
    )
  }
}

///|
async fn run_topic_list(spin_time_ms : Int) -> Result[Unit, String] {
  let cli = match new_cli_participant(false) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let result = @async.with_task_group() <| group => {
    group.spawn_bg(no_wait=true) <| () => {
      ignore(cli.participant.announce_spdp_forever(CLI_DISCOVERY_INTERVAL_MS))
    }
    match spin_discovery(cli.participant, spin_time_ms, false) {
      Ok(_) => {
        print_topic_summaries(topic_summaries(cli.participant.graph()))
        Ok(())
      }
      Err(message) => Err(message)
    }
  }
  cli.participant.close()
  result
}
