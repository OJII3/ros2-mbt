///|
async fn discover_parameter_services(
  participant : @transport.RosParticipant,
  get_service : @ros.RosService,
  get_parameter_types_service : @ros.RosService,
  set_service : @ros.RosService,
  set_atomically_service : @ros.RosService,
  list_service : @ros.RosService,
) -> Result[
  (
    @rtps.SedpEndpointData,
    @rtps.SedpEndpointData,
    @rtps.SedpEndpointData,
    @rtps.SedpEndpointData,
    @rtps.SedpEndpointData,
    @rtps.SedpEndpointData,
    @rtps.SedpEndpointData,
    @rtps.SedpEndpointData,
    @rtps.SedpEndpointData,
    @rtps.SedpEndpointData,
  ),
  String,
] {
  let mut get_request_subscription : @rtps.SedpEndpointData? = None
  let mut get_response_publication : @rtps.SedpEndpointData? = None
  let mut get_parameter_types_request_subscription : @rtps.SedpEndpointData? = None
  let mut get_parameter_types_response_publication : @rtps.SedpEndpointData? = None
  let mut set_request_subscription : @rtps.SedpEndpointData? = None
  let mut set_response_publication : @rtps.SedpEndpointData? = None
  let mut set_atomically_request_subscription : @rtps.SedpEndpointData? = None
  let mut set_atomically_response_publication : @rtps.SedpEndpointData? = None
  let mut list_request_subscription : @rtps.SedpEndpointData? = None
  let mut list_response_publication : @rtps.SedpEndpointData? = None
  while get_request_subscription is None ||
        get_response_publication is None ||
        get_parameter_types_request_subscription is None ||
        get_parameter_types_response_publication is None ||
        set_request_subscription is None ||
        set_response_publication is None ||
        set_atomically_request_subscription is None ||
        set_atomically_response_publication is None ||
        list_request_subscription is None ||
        list_response_publication is None {
    match participant.receive_discovery_once() {
      Ok((_, @transport.DiscoveryEvent::Publication(publication))) =>
        if publication.topic_name() == get_service.dds_response_name() &&
          publication.type_name() == get_service.dds_response_type_name() {
          get_response_publication = Some(publication)
        } else if publication.topic_name() ==
          get_parameter_types_service.dds_response_name() &&
          publication.type_name() ==
          get_parameter_types_service.dds_response_type_name() {
          get_parameter_types_response_publication = Some(publication)
        } else if publication.topic_name() == set_service.dds_response_name() &&
          publication.type_name() == set_service.dds_response_type_name() {
          set_response_publication = Some(publication)
        } else if publication.topic_name() ==
          set_atomically_service.dds_response_name() &&
          publication.type_name() ==
          set_atomically_service.dds_response_type_name() {
          set_atomically_response_publication = Some(publication)
        } else if publication.topic_name() == list_service.dds_response_name() &&
          publication.type_name() == list_service.dds_response_type_name() {
          list_response_publication = Some(publication)
        }
      Ok((_, @transport.DiscoveryEvent::Subscription(subscription))) =>
        if subscription.topic_name() == get_service.dds_request_name() &&
          subscription.type_name() == get_service.dds_request_type_name() {
          get_request_subscription = Some(subscription)
        } else if subscription.topic_name() ==
          get_parameter_types_service.dds_request_name() &&
          subscription.type_name() ==
          get_parameter_types_service.dds_request_type_name() {
          get_parameter_types_request_subscription = Some(subscription)
        } else if subscription.topic_name() == set_service.dds_request_name() &&
          subscription.type_name() == set_service.dds_request_type_name() {
          set_request_subscription = Some(subscription)
        } else if subscription.topic_name() ==
          set_atomically_service.dds_request_name() &&
          subscription.type_name() ==
          set_atomically_service.dds_request_type_name() {
          set_atomically_request_subscription = Some(subscription)
        } else if subscription.topic_name() == list_service.dds_request_name() &&
          subscription.type_name() == list_service.dds_request_type_name() {
          list_request_subscription = Some(subscription)
        }
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  match
    (
      get_request_subscription, get_response_publication, set_request_subscription,
      set_response_publication, list_request_subscription, list_response_publication,
      get_parameter_types_request_subscription, get_parameter_types_response_publication,
      set_atomically_request_subscription, set_atomically_response_publication,
    ) {
    (
      Some(get_request_subscription),
      Some(get_response_publication),
      Some(set_request_subscription),
      Some(set_response_publication),
      Some(list_request_subscription),
      Some(list_response_publication),
      Some(get_parameter_types_request_subscription),
      Some(get_parameter_types_response_publication),
      Some(set_atomically_request_subscription),
      Some(set_atomically_response_publication),
    ) =>
      Ok(
        (
          get_request_subscription, get_response_publication, set_request_subscription,
          set_response_publication, list_request_subscription, list_response_publication,
          get_parameter_types_request_subscription, get_parameter_types_response_publication,
          set_atomically_request_subscription, set_atomically_response_publication,
        ),
      )
    _ => Err("discovery ended without matching parameter service endpoints")
  }
}

///|
async fn set_integer_parameter(
  client : @transport.RosServiceClient,
  name : String,
  value : Int64,
) -> Result[Bool, String] {
  let writer = @cdr.Writer::new()
  writer.write_u32(1U)
  write_integer_parameter(writer, name, value)
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
  let result_count = match reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if result_count != 1 {
    return Err("SetParameters returned an unexpected number of results")
  }
  let successful = match reader.read_bool() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match reader.read_string() {
    Ok(_) => Ok(successful)
    Err(message) => Err(message)
  }
}

///|
async fn set_integer_parameter_atomically(
  client : @transport.RosServiceClient,
  name : String,
  value : Int64,
) -> Result[(Bool, String), String] {
  let writer = @cdr.Writer::new()
  writer.write_u32(1U)
  write_integer_parameter(writer, name, value)
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
  let successful = match reader.read_bool() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match reader.read_string() {
    Ok(reason) => Ok((successful, reason))
    Err(message) => Err(message)
  }
}

///|
fn write_integer_parameter(
  writer : @cdr.Writer,
  name : String,
  value : Int64,
) -> Unit {
  writer.write_string(name)
  writer.write_u8(2)
  writer.write_bool(false)
  writer.write_i64(value)
  writer.write_f64(0.0)
  writer.write_string("")
  writer.write_u32(0U)
  writer.write_u32(0U)
  writer.write_u32(0U)
  writer.write_u32(0U)
  writer.write_u32(0U)
}

///|
async fn get_integer_parameter(
  client : @transport.RosServiceClient,
  name : String,
) -> Result[Int64, String] {
  let writer = @cdr.Writer::new()
  writer.write_u32(1U)
  writer.write_string(name)
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
  let value_count = match reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if value_count != 1 {
    return Err("GetParameters returned an unexpected number of values")
  }
  let parameter_type = match reader.read_u8() {
    Ok(value) => value.to_int()
    Err(message) => return Err(message)
  }
  match reader.read_bool() {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let parameter_value = match reader.read_i64() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if parameter_type != 2 {
    return Err("GetParameters returned a non-integer parameter")
  }
  Ok(parameter_value)
}

///|
async fn get_parameter_type(
  client : @transport.RosServiceClient,
  name : String,
) -> Result[Int, String] {
  let writer = @cdr.Writer::new()
  writer.write_u32(1U)
  writer.write_string(name)
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
  let type_count = match reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if type_count != 1 {
    return Err("GetParameterTypes returned an unexpected number of types")
  }
  match reader.read_u8() {
    Ok(value) => Ok(value.to_int())
    Err(message) => Err(message)
  }
}

///|
async fn parameter_name_is_listed(
  client : @transport.RosServiceClient,
  expected_name : String,
) -> Result[Bool, String] {
  let writer = @cdr.Writer::new()
  writer.write_u32(0U)
  writer.write_u64(0UL)
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
  let name_count = match reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if name_count < 0 || name_count > reader.remaining() / 4 {
    return Err("invalid ListParameters names sequence length")
  }
  let mut found = false
  for _ in 0..<name_count {
    let name = match reader.read_string() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    if name == expected_name {
      found = true
    }
  }
  let prefix_count = match reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if prefix_count < 0 || prefix_count > reader.remaining() / 4 {
    return Err("invalid ListParameters prefixes sequence length")
  }
  for _ in 0..<prefix_count {
    match reader.read_string() {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(found)
}

///|
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
      0x4D, 0x42, 0x54, 0x52, 0x50, 0x53, 0, 0, 0, 0, 0, 48,
    ]) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let vendor_id = @rtps.VendorId::new(1, 15)
  let get_service = match
    @ros.RosService::new(
      "/demo/moon_parameter_server/get_parameters", "rcl_interfaces", "GetParameters",
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let get_parameter_types_service = match
    @ros.RosService::new(
      "/demo/moon_parameter_server/get_parameter_types", "rcl_interfaces", "GetParameterTypes",
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let set_service = match
    @ros.RosService::new(
      "/demo/moon_parameter_server/set_parameters", "rcl_interfaces", "SetParameters",
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let set_atomically_service = match
    @ros.RosService::new(
      "/demo/moon_parameter_server/set_parameters_atomically", "rcl_interfaces",
      "SetParametersAtomically",
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let list_service = match
    @ros.RosService::new(
      "/demo/moon_parameter_server/list_parameters", "rcl_interfaces", "ListParameters",
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let get_request_writer_id = @rtps.EntityId::new(b"\x00\x00\x36", 0x03).unwrap()
  let get_response_reader_id = @rtps.EntityId::new(b"\x00\x00\x37", 0x04).unwrap()
  let get_parameter_types_request_writer_id = @rtps.EntityId::new(
    b"\x00\x00\x3C", 0x03,
  ).unwrap()
  let get_parameter_types_response_reader_id = @rtps.EntityId::new(
    b"\x00\x00\x3D", 0x04,
  ).unwrap()
  let set_request_writer_id = @rtps.EntityId::new(b"\x00\x00\x38", 0x03).unwrap()
  let set_response_reader_id = @rtps.EntityId::new(b"\x00\x00\x39", 0x04).unwrap()
  let set_atomically_request_writer_id = @rtps.EntityId::new(
    b"\x00\x00\x3E", 0x03,
  ).unwrap()
  let set_atomically_response_reader_id = @rtps.EntityId::new(
    b"\x00\x00\x3F", 0x04,
  ).unwrap()
  let list_request_writer_id = @rtps.EntityId::new(b"\x00\x00\x3A", 0x03).unwrap()
  let list_response_reader_id = @rtps.EntityId::new(b"\x00\x00\x3B", 0x04).unwrap()
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
      48U,
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
  match participant.set_ros_node_identity("/demo", "moon_parameter_client") {
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
      get_service, get_request_writer_id, get_response_reader_id, "RIHS01_135a9e1c3d7cebef792f6687d7ddf99949b21a0bd9a320d863a9110a3f5cf4d6",
      "RIHS01_9fa773b46e39cc5d02db6224d8fd520bb9caeeffc2b27c96c1e59431baba9f2a",
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
      get_parameter_types_service, get_parameter_types_request_writer_id, get_parameter_types_response_reader_id,
      "RIHS01_87d7ec5ef545d4daa289d500025d31fb2437bc8b8365ca367161c4dac4be33fd",
      "RIHS01_ac1335dce67c478e669434f6ac2fbff34fcd529580f272d3006785ba8b54e47f",
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
      list_service, list_request_writer_id, list_response_reader_id, "RIHS01_a1b0b5d6b967a5b8ac5bc8563c3ea678f349e312a6a4967227c5a96bc5ce38df",
      "RIHS01_31b937b82de3612426be79f231e386259f97e8dc843e3f2845288b4bfa296bdd",
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
      set_service, set_request_writer_id, set_response_reader_id, "RIHS01_130d46386b7e84ea9ecf60608a4d83cbe5e5cb7c6cc5b712b7a4e3a6c254e932",
      "RIHS01_7a0e8140a0b8d98308fa81a5403a766e610af29a239caf54b7553227906fc266",
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
      set_atomically_service, set_atomically_request_writer_id, set_atomically_response_reader_id,
      "RIHS01_db0bd950ed5ed867a0e90b225e44dea382d762c0762ff3e0ee842190042a59e5",
      "RIHS01_31b1a38c5b0b9d893ee24da45f69638f4561c78461d82d52750f429b534502b8",
    ) {
    Ok(_) => ()
    Err(message) => {
      println(message)
      participant.close()
      return
    }
  }
  let endpoints = @async.with_task_group() <| group => {
    group.spawn_bg(no_wait=true) <| () => {
      match participant.announce_spdp_forever(1000) {
        Ok(_) => ()
        Err(message) => fail(message)
      }
    }
    discover_parameter_services(
      participant, get_service, get_parameter_types_service, set_service, set_atomically_service,
      list_service,
    )
  }
  let (
    get_request_subscription,
    get_response_publication,
    set_request_subscription,
    set_response_publication,
    list_request_subscription,
    list_response_publication,
    get_parameter_types_request_subscription,
    get_parameter_types_response_publication,
    set_atomically_request_subscription,
    set_atomically_response_publication,
  ) = match endpoints {
    Ok(value) => value
    Err(message) => {
      println(message)
      participant.close()
      return
    }
  }
  let service_wire_format = match
    participant
    .graph()
    .participant_vendor_id(get_response_publication.participant_guid()) {
    Some(vendor) if vendor == @rtps.VendorId::new(1, 16) =>
      @transport.RosServiceWireFormat::CycloneDdsPayload
    _ => @transport.RosServiceWireFormat::DdsRpcInline
  }
  let (discovery, user_socket) = participant.into_parts()
  discovery.close()
  let set_client = match
    @transport.RosServiceClient::new_with_shared_socket_and_wire_format(
      set_service, user_socket, prefix, vendor_id, set_request_writer_id, set_request_subscription,
      set_response_reader_id, set_response_publication, 1L, service_wire_format,
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      user_socket.close()
      return
    }
  }
  let get_client = match
    @transport.RosServiceClient::new_with_shared_socket_and_wire_format(
      get_service, user_socket, prefix, vendor_id, get_request_writer_id, get_request_subscription,
      get_response_reader_id, get_response_publication, 1L, service_wire_format,
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      set_client.close()
      return
    }
  }
  let list_client = match
    @transport.RosServiceClient::new_with_shared_socket_and_wire_format(
      list_service, user_socket, prefix, vendor_id, list_request_writer_id, list_request_subscription,
      list_response_reader_id, list_response_publication, 1L, service_wire_format,
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      set_client.close()
      get_client.close()
      return
    }
  }
  let get_parameter_types_client = match
    @transport.RosServiceClient::new_with_shared_socket_and_wire_format(
      get_parameter_types_service, user_socket, prefix, vendor_id, get_parameter_types_request_writer_id,
      get_parameter_types_request_subscription, get_parameter_types_response_reader_id,
      get_parameter_types_response_publication, 1L, service_wire_format,
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      set_client.close()
      get_client.close()
      list_client.close()
      return
    }
  }
  let set_succeeded = match set_integer_parameter(set_client, "answer", 99L) {
    Ok(value) => value
    Err(message) => {
      println(message)
      set_client.close()
      get_client.close()
      list_client.close()
      get_parameter_types_client.close()
      return
    }
  }
  if !set_succeeded {
    println("SetParameters rejected the integer parameter")
    set_client.close()
    get_client.close()
    list_client.close()
    get_parameter_types_client.close()
    return
  }
  println("SetParameters answer: true")
  let set_atomically_client = match
    @transport.RosServiceClient::new_with_shared_socket_and_wire_format(
      set_atomically_service, user_socket, prefix, vendor_id, set_atomically_request_writer_id,
      set_atomically_request_subscription, set_atomically_response_reader_id, set_atomically_response_publication,
      1L, service_wire_format,
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      set_client.close()
      get_client.close()
      list_client.close()
      get_parameter_types_client.close()
      return
    }
  }
  let (atomically_succeeded, atomically_reason) = match
    set_integer_parameter_atomically(set_atomically_client, "answer", 123L) {
    Ok(value) => value
    Err(message) => {
      println(message)
      set_client.close()
      get_client.close()
      list_client.close()
      get_parameter_types_client.close()
      set_atomically_client.close()
      return
    }
  }
  if !atomically_succeeded {
    println(
      "SetParametersAtomically rejected the integer parameter: " +
      atomically_reason,
    )
    set_client.close()
    get_client.close()
    list_client.close()
    get_parameter_types_client.close()
    set_atomically_client.close()
    return
  }
  println("SetParametersAtomically answer: true")
  let parameter_type = match
    get_parameter_type(get_parameter_types_client, "answer") {
    Ok(value) => value
    Err(message) => {
      println(message)
      set_client.close()
      get_client.close()
      list_client.close()
      get_parameter_types_client.close()
      set_atomically_client.close()
      return
    }
  }
  if parameter_type != 2 {
    println("GetParameterTypes did not return the integer parameter type")
    set_client.close()
    get_client.close()
    list_client.close()
    get_parameter_types_client.close()
    set_atomically_client.close()
    return
  }
  println("GetParameterTypes answer: " + parameter_type.to_string())
  let parameter_value = match get_integer_parameter(get_client, "answer") {
    Ok(value) => value
    Err(message) => {
      println(message)
      set_client.close()
      get_client.close()
      list_client.close()
      get_parameter_types_client.close()
      set_atomically_client.close()
      return
    }
  }
  if parameter_value != 123L {
    println("GetParameters did not return the updated parameter value")
    set_client.close()
    get_client.close()
    list_client.close()
    get_parameter_types_client.close()
    set_atomically_client.close()
    return
  }
  println("GetParameters answer: " + parameter_value.to_string())
  let answer_is_listed = match parameter_name_is_listed(list_client, "answer") {
    Ok(value) => value
    Err(message) => {
      println(message)
      set_client.close()
      get_client.close()
      list_client.close()
      get_parameter_types_client.close()
      set_atomically_client.close()
      return
    }
  }
  if !answer_is_listed {
    println("ListParameters did not include answer")
    set_client.close()
    get_client.close()
    list_client.close()
    get_parameter_types_client.close()
    set_atomically_client.close()
    return
  }
  println("ListParameters contains: answer")
  set_client.close()
  get_client.close()
  list_client.close()
  get_parameter_types_client.close()
  set_atomically_client.close()
}
