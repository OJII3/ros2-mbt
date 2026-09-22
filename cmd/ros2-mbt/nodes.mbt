///|
fn node_names(graph : @transport.DiscoveryGraph) -> Array[String] {
  let result : Array[String] = []
  for participant in graph.ros_participants() {
    for node in participant.node_entities_info_seq() {
      let name = if node.node_namespace() == "/" {
        "/" + node.node_name()
      } else {
        node.node_namespace() + "/" + node.node_name()
      }
      if !result.contains(name) {
        result.push(name)
      }
    }
  }
  result.sort_by(fn(left, right) { left.lexical_compare(right) })
  result
}

///|
async fn run_node_list(spin_time_ms : Int) -> Result[Unit, String] {
  let cli = match new_cli_participant(true) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let result = @async.with_task_group() <| group => {
    group.spawn_bg(no_wait=true) <| () => {
      ignore(cli.participant.announce_spdp_forever(CLI_DISCOVERY_INTERVAL_MS))
    }
    match spin_discovery(cli.participant, spin_time_ms, true) {
      Ok(_) => {
        for name in node_names(cli.participant.graph()) {
          println(name)
        }
        Ok(())
      }
      Err(message) => Err(message)
    }
  }
  cli.participant.close()
  result
}
