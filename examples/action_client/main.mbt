///|
fn action_service_wire_format(
  participant : @transport.RosParticipant,
  response_publication : @rtps.SedpEndpointData,
) -> @transport.RosServiceWireFormat {
  match
    participant
    .graph()
    .participant_vendor_id(response_publication.participant_guid()) {
    Some(vendor) if vendor == @rtps.VendorId::new(1, 16) =>
      @transport.RosServiceWireFormat::CycloneDdsPayload
    _ => @transport.RosServiceWireFormat::DdsRpcInline
  }
}

///|
async fn register_action_topic_subscription(
  participant : @transport.RosParticipant,
  prefix : @rtps.GuidPrefix,
  topic : @ros.RosTopic,
  endpoint_id : @rtps.EntityId,
  qos : @rtps.SedpQos,
  type_hash : String,
  locator : @rtps.Locator,
) -> Result[Unit, String] {
  let endpoint = match
    topic.to_sedp_with_qos_and_type_hash(
      @rtps.SedpEndpointKind::Subscription,
      @rtps.Guid::new(prefix, endpoint_id),
      qos,
      type_hash,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  endpoint.add_unicast_locator(locator)
  participant.register_endpoint(endpoint)
}

///|
async fn receive_fibonacci_feedback(
  client : @transport.RosActionClient,
  goal : @transport.RosActionGoalHandle,
) -> Result[Array[Int], String] {
  let payload = match client.receive_goal_feedback(goal) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let reader = match @cdr.Reader::from_bytes(payload) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let sequence_length = match reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if sequence_length < 0 || sequence_length > reader.remaining() / 4 {
    return Err("invalid Fibonacci feedback sequence length")
  }
  let sequence : Array[Int] = []
  for _ in 0..<sequence_length {
    match reader.read_i32() {
      Ok(value) => sequence.push(value)
      Err(message) => return Err(message)
    }
  }
  Ok(sequence)
}

///|
fn close_action_client_io(
  send_goal_client : @transport.RosServiceClient,
  feedback_subscription : @transport.ReliableRosSubscription,
  status_subscription : @transport.ReliableRosSubscription,
) -> Unit {
  send_goal_client.close()
  feedback_subscription.close()
  status_subscription.close()
}

///|
fn format_int_sequence(sequence : Array[Int]) -> String {
  let mut sequence_text = ""
  for index in 0..<sequence.length() {
    if index > 0 {
      sequence_text += ", "
    }
    sequence_text += sequence[index].to_string()
  }
  sequence_text
}

///|
async fn main {
  let cancel_requested = @env.get_env_var("ROS2_MBT_CANCEL_GOAL") == Some("1")
  let action_package = match @env.get_env_var("ROS2_MBT_ACTION_PACKAGE") {
    Some(value) => value
    None => "example_interfaces"
  }
  let (
    feedback_type_hash,
    send_goal_request_type_hash,
    send_goal_response_type_hash,
    get_result_request_type_hash,
    get_result_response_type_hash,
  ) = match action_package {
    "example_interfaces" =>
      (
        "RIHS01_c1de71afd52e49a89c53d8262366884185bc0a02f78ce051c4e46b0a7fe59bb2",
        "RIHS01_3d088942b413247db536576f0286768c6be8fcd5d0c9a5d544f359fba090a238",
        "RIHS01_d8c07bb3d5b766fe4b43159c9a5222af5214e2fcc29229b991d826166c512be1",
        "RIHS01_c8a4f5e7d13b81286ee1043e2ecd084281cecf1ff06aaa799464f5f15479f003",
        "RIHS01_6021dc98ab9b4bbe395e48aa4de81ee5f68eb570f88358affcc648146668b24f",
      )
    "action_tutorials_interfaces" =>
      (
        "RIHS01_e852234f7e7085fc3e14da27175b5b56a59463eea51e9146e8da58a5115f5f3d",
        "RIHS01_cf867fa8462d62fc5436ec5605ff7894053a03a856d4bbaaef97808389ded602",
        "RIHS01_7fbc4b8abac3cd2a14e146c4b635ecee917cb7ffcad38868d8afa4a31115b542",
        "RIHS01_b200a8bd0b94170de44d257a5147443fb863c3e608fcda16399e090018b1af0d",
        "RIHS01_b3385a6fc65e215c75cd72821baaf303335df6ead7c7be343d2f2ff94bdf29b6",
      )
    _ => {
      println("unsupported ROS action package: " + action_package)
      return
    }
  }
  let config = match @config.load() {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let prefix = match
    @rtps.GuidPrefix::from_array([
      0x4D,
      0x42,
      0x54,
      0x52,
      0x50,
      0x53,
      0,
      0,
      0,
      0,
      0,
      if cancel_requested {
        47
      } else {
        46
      },
    ]) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let vendor_id = @rtps.VendorId::new(1, 15)
  let action = match
    @ros.RosAction::new("/fibonacci", action_package, "Fibonacci") {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let send_goal = action.send_goal_service()
  let get_result = action.get_result_service()
  let cancel_goal = action.cancel_goal_service()
  let feedback_topic = action.feedback_topic()
  let status_topic = action.status_topic()
  let send_goal_request_id = @rtps.EntityId::new(b"\x00\x00\x30", 0x03).unwrap()
  let send_goal_response_id = @rtps.EntityId::new(b"\x00\x00\x31", 0x04).unwrap()
  let get_result_request_id = @rtps.EntityId::new(b"\x00\x00\x32", 0x03).unwrap()
  let get_result_response_id = @rtps.EntityId::new(b"\x00\x00\x33", 0x04).unwrap()
  let cancel_goal_request_id = @rtps.EntityId::new(b"\x00\x00\x34", 0x03).unwrap()
  let cancel_goal_response_id = @rtps.EntityId::new(b"\x00\x00\x35", 0x04).unwrap()
  let graph_publication_id = @rtps.EntityId::new(
    b"gph",
    @ros.ROS_GRAPH_PUBLICATION_ENTITY_KIND,
  ).unwrap()
  let graph_subscription_id = @rtps.EntityId::new(
    b"gph",
    @ros.ROS_GRAPH_SUBSCRIPTION_ENTITY_KIND,
  ).unwrap()
  let participant = match
    @transport.RosParticipant::new_ddsi(
      prefix,
      vendor_id,
      config.domain_id,
      46U,
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
  match
    participant.set_ros_node_identity("/demo", "moon_fibonacci_action_client") {
    Ok(_) => ()
    Err(message) => {
      println(message)
      participant.close()
      return
    }
  }
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
  let feedback_reader_id = @rtps.EntityId::new(b"\x00\x00\x36", 0x04).unwrap()
  let status_reader_id = @rtps.EntityId::new(b"\x00\x00\x37", 0x04).unwrap()
  let feedback_socket = @transport.Udp::bind(@socket.Addr::new(config.ip, 0))
  let status_socket = @transport.Udp::bind(@socket.Addr::new(config.ip, 0))
  let feedback_locator = match feedback_socket.local_unicast_locator() {
    Ok(value) => value
    Err(message) => {
      println(message)
      feedback_socket.close()
      status_socket.close()
      participant.close()
      return
    }
  }
  let status_locator = match status_socket.local_unicast_locator() {
    Ok(value) => value
    Err(message) => {
      println(message)
      feedback_socket.close()
      status_socket.close()
      participant.close()
      return
    }
  }
  match
    register_action_topic_subscription(
      participant,
      prefix,
      feedback_topic,
      feedback_reader_id,
      @rtps.SedpQos::new(
        @rtps.RELIABILITY_RELIABLE,
        @rtps.DURABILITY_VOLATILE,
        @rtps.HISTORY_KEEP_LAST,
        10,
      ),
      feedback_type_hash,
      feedback_locator,
    ) {
    Ok(_) => ()
    Err(message) => {
      println(message)
      feedback_socket.close()
      status_socket.close()
      participant.close()
      return
    }
  }
  match
    register_action_topic_subscription(
      participant,
      prefix,
      status_topic,
      status_reader_id,
      @rtps.SedpQos::new(
        @rtps.RELIABILITY_RELIABLE,
        @rtps.DURABILITY_TRANSIENT_LOCAL,
        @rtps.HISTORY_KEEP_LAST,
        1,
      ),
      "RIHS01_6c1684b00f177d37438febe6e709fc4e2b0d4248dca4854946f9ed8b30cda83e",
      status_locator,
    ) {
    Ok(_) => ()
    Err(message) => {
      println(message)
      feedback_socket.close()
      status_socket.close()
      participant.close()
      return
    }
  }
  match
    participant.register_service_client_with_type_hashes(
      send_goal, send_goal_request_id, send_goal_response_id, send_goal_request_type_hash,
      send_goal_response_type_hash,
    ) {
    Ok(_) => ()
    Err(message) => {
      println(message)
      feedback_socket.close()
      status_socket.close()
      participant.close()
      return
    }
  }
  match
    participant.register_service_client_with_type_hashes(
      get_result, get_result_request_id, get_result_response_id, get_result_request_type_hash,
      get_result_response_type_hash,
    ) {
    Ok(_) => ()
    Err(message) => {
      println(message)
      feedback_socket.close()
      status_socket.close()
      participant.close()
      return
    }
  }
  match
    participant.register_service_client_with_type_hashes(
      cancel_goal, cancel_goal_request_id, cancel_goal_response_id, "RIHS01_3d3c84653c1f96918086887e1dcb236faec88b81a5b14fd4cf4840065bcdf8af",
      "RIHS01_35e682cf3f510e83c70a82a4aac888496dedee56773bf9d8e5e0aa81f9e1c960",
    ) {
    Ok(_) => ()
    Err(message) => {
      println(message)
      feedback_socket.close()
      status_socket.close()
      participant.close()
      return
    }
  }
  let discovered_endpoints = @async.with_task_group() <| group => {
    group.spawn_bg(no_wait=true) <| () => {
      match participant.announce_spdp_forever(1000) {
        Ok(_) => ()
        Err(message) => fail(message)
      }
    }
    @transport.RosActionEndpoints::discover(participant, action)
  }
  let endpoints = match discovered_endpoints {
    Ok(value) => value
    Err(message) => {
      println(message)
      feedback_socket.close()
      status_socket.close()
      participant.close()
      return
    }
  }
  let send_goal_wire_format = action_service_wire_format(
    participant,
    endpoints.send_goal_response_publication(),
  )
  let get_result_wire_format = action_service_wire_format(
    participant,
    endpoints.get_result_response_publication(),
  )
  let cancel_goal_wire_format = action_service_wire_format(
    participant,
    endpoints.cancel_goal_response_publication(),
  )
  let (discovery, user_socket) = participant.into_parts()
  discovery.close()
  let send_goal_client = match
    @transport.RosServiceClient::new_with_shared_socket_and_wire_format(
      send_goal,
      user_socket,
      prefix,
      vendor_id,
      send_goal_request_id,
      endpoints.send_goal_request_subscription(),
      send_goal_response_id,
      endpoints.send_goal_response_publication(),
      1L,
      send_goal_wire_format,
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      user_socket.close()
      feedback_socket.close()
      status_socket.close()
      return
    }
  }
  let get_result_client = match
    @transport.RosServiceClient::new_with_shared_socket_and_wire_format(
      get_result,
      user_socket,
      prefix,
      vendor_id,
      get_result_request_id,
      endpoints.get_result_request_subscription(),
      get_result_response_id,
      endpoints.get_result_response_publication(),
      1L,
      get_result_wire_format,
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      send_goal_client.close()
      feedback_socket.close()
      status_socket.close()
      return
    }
  }
  let cancel_goal_client = match
    @transport.RosServiceClient::new_with_shared_socket_and_wire_format(
      cancel_goal,
      user_socket,
      prefix,
      vendor_id,
      cancel_goal_request_id,
      endpoints.cancel_goal_request_subscription(),
      cancel_goal_response_id,
      endpoints.cancel_goal_response_publication(),
      1L,
      cancel_goal_wire_format,
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      send_goal_client.close()
      feedback_socket.close()
      status_socket.close()
      return
    }
  }
  let feedback_subscription = match
    @transport.ReliableRosSubscription::new_for_publication(
      feedback_topic,
      feedback_socket,
      prefix,
      vendor_id,
      feedback_reader_id,
      endpoints.feedback_publication(),
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      send_goal_client.close()
      feedback_socket.close()
      status_socket.close()
      return
    }
  }
  let status_subscription = match
    @transport.ReliableRosSubscription::new_for_publication(
      status_topic,
      status_socket,
      prefix,
      vendor_id,
      status_reader_id,
      endpoints.status_publication(),
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      send_goal_client.close()
      feedback_subscription.close()
      status_socket.close()
      return
    }
  }
  let action_client = match
    @transport.RosActionClient::new(
      action, send_goal_client, get_result_client, cancel_goal_client, feedback_subscription,
      status_subscription,
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      close_action_client_io(
        send_goal_client, feedback_subscription, status_subscription,
      )
      return
    }
  }

  let goal_id = Bytes::from_array([
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    if cancel_requested {
      17
    } else {
      16
    },
  ])
  let goal_order = 6
  let send_goal_writer = @cdr.Writer::new()
  send_goal_writer.write_i32(goal_order)
  let goal = match
    action_client.send_goal(goal_id, send_goal_writer.to_bytes()) {
    Ok(value) => value
    Err(message) => {
      println(message)
      close_action_client_io(
        send_goal_client, feedback_subscription, status_subscription,
      )
      return
    }
  }
  println("Fibonacci goal accepted: " + goal.accepted().to_string())
  if !goal.accepted() {
    close_action_client_io(
      send_goal_client, feedback_subscription, status_subscription,
    )
    return
  }

  let feedback_sequence = match
    receive_fibonacci_feedback(action_client, goal) {
    Ok(value) => value
    Err(message) => {
      println(message)
      close_action_client_io(
        send_goal_client, feedback_subscription, status_subscription,
      )
      return
    }
  }
  println(
    "Fibonacci feedback: [" + format_int_sequence(feedback_sequence) + "]",
  )

  if cancel_requested {
    let cancel_response = match action_client.cancel_goal(goal) {
      Ok(value) => value
      Err(message) => {
        println(message)
        close_action_client_io(
          send_goal_client, feedback_subscription, status_subscription,
        )
        return
      }
    }
    let mut found_goal = false
    for canceled_goal in cancel_response.goals_canceling() {
      if canceled_goal.goal_id() == goal.goal_id() {
        found_goal = true
      }
    }
    if !found_goal {
      println("CancelGoal response did not include the requested goal")
      close_action_client_io(
        send_goal_client, feedback_subscription, status_subscription,
      )
      return
    }
    let cancel_return_code = cancel_response.return_code()
    println("Fibonacci cancel return code: " + cancel_return_code.to_string())
    if cancel_return_code != 0 {
      close_action_client_io(
        send_goal_client, feedback_subscription, status_subscription,
      )
      return
    }
  }

  let get_result_payload = match action_client.get_result(goal) {
    Ok(value) => value
    Err(message) => {
      println(message)
      close_action_client_io(
        send_goal_client, feedback_subscription, status_subscription,
      )
      return
    }
  }
  let get_result_reader = match @cdr.Reader::from_bytes(get_result_payload) {
    Ok(value) => value
    Err(message) => {
      println(message)
      close_action_client_io(
        send_goal_client, feedback_subscription, status_subscription,
      )
      return
    }
  }
  let status = match get_result_reader.read_i8() {
    Ok(value) => value
    Err(message) => {
      println(message)
      close_action_client_io(
        send_goal_client, feedback_subscription, status_subscription,
      )
      return
    }
  }
  let sequence_length = match get_result_reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => {
      println(message)
      close_action_client_io(
        send_goal_client, feedback_subscription, status_subscription,
      )
      return
    }
  }
  if sequence_length < 0 || sequence_length > get_result_reader.remaining() / 4 {
    println("invalid Fibonacci result sequence length")
    close_action_client_io(
      send_goal_client, feedback_subscription, status_subscription,
    )
    return
  }
  let sequence : Array[Int] = []
  for _ in 0..<sequence_length {
    match get_result_reader.read_i32() {
      Ok(value) => sequence.push(value)
      Err(message) => {
        println(message)
        close_action_client_io(
          send_goal_client, feedback_subscription, status_subscription,
        )
        return
      }
    }
  }
  println("Fibonacci result status: " + status.to_string())
  println("Fibonacci result: [" + format_int_sequence(sequence) + "]")
  let status_topic_goal_status = match
    action_client.receive_goal_terminal_status(goal) {
    Ok(value) => value
    Err(message) => {
      println(message)
      close_action_client_io(
        send_goal_client, feedback_subscription, status_subscription,
      )
      return
    }
  }
  if status_topic_goal_status.status() != status {
    println(
      "Fibonacci result and GoalStatusArray reported different terminal states",
    )
    close_action_client_io(
      send_goal_client, feedback_subscription, status_subscription,
    )
    return
  }
  println(
    "Fibonacci status topic: " + status_topic_goal_status.status().to_string(),
  )
  action_client.close()
}
