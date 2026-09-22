///|
/// Discover the service endpoints.
async fn discover_service(
  participant : @transport.RosParticipant,
  service : @ros.RosService,
) -> Result[(@rtps.SedpEndpointData, @rtps.SedpEndpointData), String] {
  let mut request_publication : @rtps.SedpEndpointData? = None
  let mut response_subscription : @rtps.SedpEndpointData? = None
  // Graph discovery may already have consumed these SEDP events.
  for publication in participant.graph().publications() {
    if publication.topic_name() == service.dds_request_name() &&
      publication.type_name() == service.dds_request_type_name() {
      request_publication = Some(publication)
    }
  }
  for subscription in participant.graph().subscriptions() {
    if subscription.topic_name() == service.dds_response_name() &&
      subscription.type_name() == service.dds_response_type_name() {
      response_subscription = Some(subscription)
    }
  }
  while request_publication is None || response_subscription is None {
    match participant.receive_discovery_once() {
      Ok((_, Publication(publication))) =>
        if publication.topic_name() == service.dds_request_name() &&
          publication.type_name() == service.dds_request_type_name() {
          request_publication = Some(publication)
        }
      Ok((_, Subscription(subscription))) =>
        if subscription.topic_name() == service.dds_response_name() &&
          subscription.type_name() == service.dds_response_type_name() {
          response_subscription = Some(subscription)
        }
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  match (request_publication, response_subscription) {
    (Some(request_publication), Some(response_subscription)) =>
      Ok((request_publication, response_subscription))
    _ => Err("discovery ended without matching service endpoints")
  }
}

///|
async fn announce_ros_graph_info(
  participant : @transport.RosParticipant,
) -> Result[Unit, String] {
  let mut quiet_periods = 0
  println("Waiting for ROS graph discovery readers")
  while participant.ros_discovery_publisher_count() == 0 || quiet_periods < 12 {
    let graph_publisher_count = participant.ros_discovery_publisher_count()
    let received = if graph_publisher_count > 0 {
      @async.with_timeout_opt(250, async fn() {
        participant.receive_discovery_once()
      })
    } else {
      Some(participant.receive_discovery_once())
    }
    match received {
      None => quiet_periods += 1
      Some(Ok(_)) =>
        if participant.ros_discovery_publisher_count() > graph_publisher_count {
          quiet_periods = 0
        }
      Some(Err(message)) => return Err(message)
    }
  }
  println(
    "ROS graph discovery readers: " +
    participant.ros_discovery_publisher_count().to_string(),
  )
  let graph_info = match
    participant.participant_entities_info("/demo", "moon_add_two_ints_server") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  for _ in 0..<3 {
    match participant.publish_ros_discovery_info(graph_info) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    @async.sleep(250)
  }
  println("Announced ROS graph metadata for /demo/moon_add_two_ints_server")
  Ok(())
}

///|
/// Serve one `example_interfaces/srv/AddTwoInts` request over ROS 2 DDS.
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
      0x4D, 0x42, 0x54, 0x52, 0x50, 0x53, 0, 0, 0, 0, 0, 44,
    ]) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let vendor_id = @rtps.VendorId::new(1, 15)
  let service = match
    @ros.RosService::new("/add_two_ints", "example_interfaces", "AddTwoInts") {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let request_reader_id = match @rtps.EntityId::new(b"\x00\x00\x2C", 0x04) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let response_writer_id = match @rtps.EntityId::new(b"\x00\x00\x2D", 0x03) {
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
      44U,
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
  match participant.set_ros_node_identity("/demo", "moon_add_two_ints_server") {
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
    participant.register_service_server_with_type_hashes(
      service, request_reader_id, response_writer_id, "RIHS01_000c5fd92d6b2e1a05949348f584d6d652adea1e92d691792011ac2273508302",
      "RIHS01_de5c030d4af33cba2749310b249737b631594703f9300495f48bffb2b44dcc2f",
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
    match announce_ros_graph_info(participant) {
      Ok(_) => discover_service(participant, service)
      Err(message) => Err(message)
    }
  }
  let (request_publication, response_subscription) = match
    discovered_endpoints {
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
    .participant_vendor_id(request_publication.participant_guid()) {
    Some(vendor) if vendor == @rtps.VendorId::new(1, 16) =>
      @transport.RosServiceWireFormat::CycloneDdsPayload
    _ => DdsRpcInline
  }
  let (discovery, user_socket) = participant.into_parts()
  discovery.close()
  let server = match
    @transport.RosServiceServer::new_with_shared_socket_and_wire_format(
      service, user_socket, prefix, vendor_id, request_reader_id, request_publication,
      response_writer_id, response_subscription, 1L, service_wire_format,
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let (request_payload, request_identity, _) = match server.receive_request() {
    Ok(value) => value
    Err(message) => {
      println(message)
      server.close()
      return
    }
  }
  let request_reader = match @cdr.Reader::from_bytes(request_payload) {
    Ok(value) => value
    Err(message) => {
      println(message)
      server.close()
      return
    }
  }
  let a = match request_reader.read_i64() {
    Ok(value) => value
    Err(message) => {
      println(message)
      server.close()
      return
    }
  }
  let b = match request_reader.read_i64() {
    Ok(value) => value
    Err(message) => {
      println(message)
      server.close()
      return
    }
  }
  let response_writer = @cdr.Writer::new()
  response_writer.write_i64(a + b)
  match server.respond(request_identity, response_writer.to_bytes()) {
    Ok(_) => println("served AddTwoInts request")
    Err(message) => println(message)
  }
  server.close()
}
