///|
async fn discover_action_services(
  participant : @transport.RosParticipant,
  send_goal : @ros.RosService,
  get_result : @ros.RosService,
  cancel_goal : @ros.RosService,
) -> Result[
  (
    @rtps.SedpEndpointData,
    @rtps.SedpEndpointData,
    @rtps.SedpEndpointData,
    @rtps.SedpEndpointData,
    @rtps.SedpEndpointData,
    @rtps.SedpEndpointData,
  ),
  String,
] {
  let mut send_goal_request_subscription : @rtps.SedpEndpointData? = None
  let mut send_goal_response_publication : @rtps.SedpEndpointData? = None
  let mut get_result_request_subscription : @rtps.SedpEndpointData? = None
  let mut get_result_response_publication : @rtps.SedpEndpointData? = None
  let mut cancel_goal_request_subscription : @rtps.SedpEndpointData? = None
  let mut cancel_goal_response_publication : @rtps.SedpEndpointData? = None
  while send_goal_request_subscription is None ||
        send_goal_response_publication is None ||
        get_result_request_subscription is None ||
        get_result_response_publication is None ||
        cancel_goal_request_subscription is None ||
        cancel_goal_response_publication is None {
    match participant.receive_discovery_once() {
      Ok((_, @transport.DiscoveryEvent::Publication(publication))) => {
        if publication.topic_name() == send_goal.dds_response_name() &&
          publication.type_name() == send_goal.dds_response_type_name() {
          send_goal_response_publication = Some(publication)
        }
        if publication.topic_name() == get_result.dds_response_name() &&
          publication.type_name() == get_result.dds_response_type_name() {
          get_result_response_publication = Some(publication)
        }
        if publication.topic_name() == cancel_goal.dds_response_name() &&
          publication.type_name() == cancel_goal.dds_response_type_name() {
          cancel_goal_response_publication = Some(publication)
        }
      }
      Ok((_, @transport.DiscoveryEvent::Subscription(subscription))) => {
        if subscription.topic_name() == send_goal.dds_request_name() &&
          subscription.type_name() == send_goal.dds_request_type_name() {
          send_goal_request_subscription = Some(subscription)
        }
        if subscription.topic_name() == get_result.dds_request_name() &&
          subscription.type_name() == get_result.dds_request_type_name() {
          get_result_request_subscription = Some(subscription)
        }
        if subscription.topic_name() == cancel_goal.dds_request_name() &&
          subscription.type_name() == cancel_goal.dds_request_type_name() {
          cancel_goal_request_subscription = Some(subscription)
        }
      }
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  match
    (
      send_goal_request_subscription, send_goal_response_publication, get_result_request_subscription,
      get_result_response_publication, cancel_goal_request_subscription, cancel_goal_response_publication,
    ) {
    (
      Some(send_goal_request_subscription),
      Some(send_goal_response_publication),
      Some(get_result_request_subscription),
      Some(get_result_response_publication),
      Some(cancel_goal_request_subscription),
      Some(cancel_goal_response_publication),
    ) =>
      Ok(
        (
          send_goal_request_subscription, send_goal_response_publication, get_result_request_subscription,
          get_result_response_publication, cancel_goal_request_subscription, cancel_goal_response_publication,
        ),
      )
    _ => Err("discovery ended without matching ROS action services")
  }
}

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
async fn request_goal_cancel(
  client : @transport.RosServiceClient,
  goal_id : Bytes,
) -> Result[Int, String] {
  let writer = @cdr.Writer::new()
  writer.write_byte_array(goal_id)
  writer.write_i32(0)
  writer.write_u32(0U)
  let identity = match client.request(writer.to_bytes()) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let (payload, _) = match client.receive_response(identity) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let reader = match @cdr.Reader::from_bytes(payload) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let return_code = match reader.read_i8() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let goals_canceling_length = match reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if goals_canceling_length <= 0 ||
    goals_canceling_length > reader.remaining() / 24 {
    return Err("invalid CancelGoal goals_canceling sequence")
  }
  let mut found_goal = false
  for _ in 0..<goals_canceling_length {
    let canceled_goal_id = match reader.read_byte_array(16) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    match (reader.read_i32(), reader.read_u32()) {
      (Ok(_), Ok(_)) => ()
      (Err(message), _) | (_, Err(message)) => return Err(message)
    }
    if canceled_goal_id == goal_id {
      found_goal = true
    }
  }
  if !found_goal {
    return Err("CancelGoal response did not include the requested goal")
  }
  Ok(return_code)
}

///|
async fn main {
  let cancel_requested = @env.get_env_var("ROS2_MBT_CANCEL_GOAL") == Some("1")
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
    @ros.RosAction::new("/fibonacci", "example_interfaces", "Fibonacci") {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let send_goal = action.send_goal_service()
  let get_result = action.get_result_service()
  let cancel_goal = action.cancel_goal_service()
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
  match
    participant.register_service_client_with_type_hashes(
      send_goal, send_goal_request_id, send_goal_response_id, "RIHS01_3d088942b413247db536576f0286768c6be8fcd5d0c9a5d544f359fba090a238",
      "RIHS01_d8c07bb3d5b766fe4b43159c9a5222af5214e2fcc29229b991d826166c512be1",
    ) {
    Ok(_) => ()
    Err(message) => {
      println(message)
      participant.close()
      return
    }
  }
  match
    participant.register_service_client_with_type_hashes(
      get_result, get_result_request_id, get_result_response_id, "RIHS01_c8a4f5e7d13b81286ee1043e2ecd084281cecf1ff06aaa799464f5f15479f003",
      "RIHS01_6021dc98ab9b4bbe395e48aa4de81ee5f68eb570f88358affcc648146668b24f",
    ) {
    Ok(_) => ()
    Err(message) => {
      println(message)
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
    discover_action_services(participant, send_goal, get_result, cancel_goal)
  }
  let (
    send_goal_request_subscription,
    send_goal_response_publication,
    get_result_request_subscription,
    get_result_response_publication,
    cancel_goal_request_subscription,
    cancel_goal_response_publication,
  ) = match discovered_endpoints {
    Ok(value) => value
    Err(message) => {
      println(message)
      participant.close()
      return
    }
  }
  let send_goal_wire_format = action_service_wire_format(
    participant, send_goal_response_publication,
  )
  let get_result_wire_format = action_service_wire_format(
    participant, get_result_response_publication,
  )
  let cancel_goal_wire_format = action_service_wire_format(
    participant, cancel_goal_response_publication,
  )
  let (discovery, user_socket) = participant.into_parts()
  discovery.close()
  let send_goal_client = match
    @transport.RosServiceClient::new_with_shared_socket_and_wire_format(
      send_goal, user_socket, prefix, vendor_id, send_goal_request_id, send_goal_request_subscription,
      send_goal_response_id, send_goal_response_publication, 1L, send_goal_wire_format,
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      user_socket.close()
      return
    }
  }
  let get_result_client = match
    @transport.RosServiceClient::new_with_shared_socket_and_wire_format(
      get_result, user_socket, prefix, vendor_id, get_result_request_id, get_result_request_subscription,
      get_result_response_id, get_result_response_publication, 1L, get_result_wire_format,
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      send_goal_client.close()
      return
    }
  }
  let cancel_goal_client = match
    @transport.RosServiceClient::new_with_shared_socket_and_wire_format(
      cancel_goal, user_socket, prefix, vendor_id, cancel_goal_request_id, cancel_goal_request_subscription,
      cancel_goal_response_id, cancel_goal_response_publication, 1L, cancel_goal_wire_format,
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      send_goal_client.close()
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
  send_goal_writer.write_byte_array(goal_id)
  send_goal_writer.write_i32(goal_order)
  let send_goal_identity = match
    send_goal_client.request(send_goal_writer.to_bytes()) {
    Ok(value) => value
    Err(message) => {
      println(message)
      send_goal_client.close()
      return
    }
  }
  let (send_goal_payload, _) = match
    send_goal_client.receive_response(send_goal_identity) {
    Ok(value) => value
    Err(message) => {
      println(message)
      send_goal_client.close()
      return
    }
  }
  let send_goal_reader = match @cdr.Reader::from_bytes(send_goal_payload) {
    Ok(value) => value
    Err(message) => {
      println(message)
      send_goal_client.close()
      return
    }
  }
  let accepted = match send_goal_reader.read_bool() {
    Ok(value) => value
    Err(message) => {
      println(message)
      send_goal_client.close()
      return
    }
  }
  match (send_goal_reader.read_i32(), send_goal_reader.read_u32()) {
    (Ok(_), Ok(_)) => ()
    (Err(message), _) | (_, Err(message)) => {
      println(message)
      send_goal_client.close()
      return
    }
  }
  println("Fibonacci goal accepted: " + accepted.to_string())
  if !accepted {
    send_goal_client.close()
    return
  }

  if cancel_requested {
    let cancel_return_code = match
      request_goal_cancel(cancel_goal_client, goal_id) {
      Ok(value) => value
      Err(message) => {
        println(message)
        send_goal_client.close()
        return
      }
    }
    println("Fibonacci cancel return code: " + cancel_return_code.to_string())
    if cancel_return_code != 0 {
      send_goal_client.close()
      return
    }
  }

  let get_result_writer = @cdr.Writer::new()
  get_result_writer.write_byte_array(goal_id)
  let get_result_identity = match
    get_result_client.request(get_result_writer.to_bytes()) {
    Ok(value) => value
    Err(message) => {
      println(message)
      send_goal_client.close()
      return
    }
  }
  let (get_result_payload, _) = match
    get_result_client.receive_response(get_result_identity) {
    Ok(value) => value
    Err(message) => {
      println(message)
      send_goal_client.close()
      return
    }
  }
  let get_result_reader = match @cdr.Reader::from_bytes(get_result_payload) {
    Ok(value) => value
    Err(message) => {
      println(message)
      send_goal_client.close()
      return
    }
  }
  let status = match get_result_reader.read_i8() {
    Ok(value) => value
    Err(message) => {
      println(message)
      send_goal_client.close()
      return
    }
  }
  let sequence_length = match get_result_reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => {
      println(message)
      send_goal_client.close()
      return
    }
  }
  if sequence_length < 0 || sequence_length > get_result_reader.remaining() / 4 {
    println("invalid Fibonacci result sequence length")
    send_goal_client.close()
    return
  }
  let sequence : Array[Int] = []
  for _ in 0..<sequence_length {
    match get_result_reader.read_i32() {
      Ok(value) => sequence.push(value)
      Err(message) => {
        println(message)
        send_goal_client.close()
        return
      }
    }
  }
  let mut sequence_text = ""
  for index in 0..<sequence.length() {
    if index > 0 {
      sequence_text += ", "
    }
    sequence_text += sequence[index].to_string()
  }
  println("Fibonacci result status: " + status.to_string())
  println("Fibonacci result: [" + sequence_text + "]")
  // Both service clients share the participant's user socket.
  send_goal_client.close()
}
