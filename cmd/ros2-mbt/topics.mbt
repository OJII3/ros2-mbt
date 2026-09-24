///|
struct TopicSummary {
  ros_name : String
  type_names : Array[String]
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
fn ros_topic_is_hidden(ros_name : String) -> Bool {
  for token in ros_name.split("/").collect() {
    if token.has_prefix("_") {
      return true
    }
  }
  false
}

///|
fn add_topic_endpoint(
  topics : Array[TopicSummary],
  endpoint : @rtps.SedpEndpointData,
  include_hidden_topics : Bool,
) -> Unit {
  let ros_name = match ros_topic_name_from_dds(endpoint.topic_name()) {
    Some(value) => value
    None => return
  }
  if !include_hidden_topics && ros_topic_is_hidden(ros_name) {
    return
  }
  let type_name = ros_type_name_from_dds(endpoint.type_name())
  for topic in topics {
    if topic.ros_name == ros_name {
      if !topic.type_names.contains(type_name) {
        topic.type_names.push(type_name)
      }
      match endpoint.kind() {
        Publication => topic.publishers += 1
        Subscription => topic.subscriptions += 1
      }
      return
    }
  }
  let summary = {
    ros_name,
    type_names: [type_name],
    publishers: 0,
    subscriptions: 0,
  }
  match endpoint.kind() {
    Publication => summary.publishers = 1
    Subscription => summary.subscriptions = 1
  }
  topics.push(summary)
}

///|
fn topic_summaries(
  graph : @transport.DiscoveryGraph,
  include_hidden_topics : Bool,
) -> Array[TopicSummary] {
  let topics : Array[TopicSummary] = []
  for publication in graph.publications() {
    add_topic_endpoint(topics, publication, include_hidden_topics)
  }
  for subscription in graph.subscriptions() {
    add_topic_endpoint(topics, subscription, include_hidden_topics)
  }
  topics.sort_by(fn(left, right) {
    left.ros_name.lexical_compare(right.ros_name)
  })
  for topic in topics {
    topic.type_names.sort_by(fn(left, right) { left.lexical_compare(right) })
  }
  topics
}

///|
fn print_topic_list(topics : Array[TopicSummary], show_types : Bool) -> Unit {
  for topic in topics {
    let type_suffix = if show_types {
      " [" + topic.type_names.join(", ") + "]"
    } else {
      ""
    }
    println(topic.ros_name + type_suffix)
  }
}

///|
fn print_topic_verbose_section(
  topics : Array[TopicSummary],
  publishers : Bool,
) -> Unit {
  for topic in topics {
    let count = if publishers { topic.publishers } else { topic.subscriptions }
    if count == 0 {
      continue
    }
    let endpoint_word = if publishers { "publisher" } else { "subscriber" }
    let plural_suffix = if count == 1 { "" } else { "s" }
    println(
      " * " +
      topic.ros_name +
      " [" +
      topic.type_names.join(", ") +
      "] " +
      count.to_string() +
      " " +
      endpoint_word +
      plural_suffix,
    )
  }
}

///|
fn print_topic_list_verbose(topics : Array[TopicSummary]) -> Unit {
  println("Published topics:")
  print_topic_verbose_section(topics, true)
  println("")
  println("Subscribed topics:")
  print_topic_verbose_section(topics, false)
  println("")
}

///|
fn print_topic_summaries(
  topics : Array[TopicSummary],
  show_types : Bool,
  verbose : Bool,
  count_topics : Bool,
) -> Unit {
  if count_topics {
    println(topics.length().to_string())
  } else if topics.length() > 0 {
    if verbose {
      print_topic_list_verbose(topics)
    } else {
      print_topic_list(topics, show_types)
    }
  }
}

///|
async fn run_topic_list(
  spin_time_ms : Int,
  show_types : Bool,
  verbose : Bool,
  count_topics : Bool,
  include_hidden_topics : Bool,
) -> Result[Unit, String] {
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
        print_topic_summaries(
          topic_summaries(cli.participant.graph(), include_hidden_topics),
          show_types,
          verbose,
          count_topics,
        )
        Ok(())
      }
      Err(message) => Err(message)
    }
  }
  cli.participant.close()
  result
}
