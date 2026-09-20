///|
/// Discover the service endpoints.
async fn discover_service(
  participant : @transport.RosParticipant,
  service : @ros.RosService,
) -> Result[(@rtps.SedpEndpointData, @rtps.SedpEndpointData), String] {
  let mut request_subscription : @rtps.SedpEndpointData? = None
  let mut response_publication : @rtps.SedpEndpointData? = None
  while request_subscription is None || response_publication is None {
    match participant.receive_discovery_once() {
      Ok((_, @transport.DiscoveryEvent::Publication(publication))) =>
        if publication.topic_name() == service.dds_response_name() &&
          publication.type_name() == service.dds_response_type_name() {
          response_publication = Some(publication)
        }
      Ok((_, @transport.DiscoveryEvent::Subscription(subscription))) =>
        if subscription.topic_name() == service.dds_request_name() &&
          subscription.type_name() == service.dds_request_type_name() {
          request_subscription = Some(subscription)
        }
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  match (request_subscription, response_publication) {
    (Some(request_subscription), Some(response_publication)) =>
      Ok((request_subscription, response_publication))
    _ => Err("discovery ended without matching service endpoints")
  }
}

///|
/// Call one `example_interfaces/srv/AddTwoInts` service over ROS 2 DDS.
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
      0x4D, 0x42, 0x54, 0x52, 0x50, 0x53, 0, 0, 0, 0, 0, 45,
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
  let request_writer_id = match @rtps.EntityId::new(b"\x00\x00\x2E", 0x03) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let response_reader_id = match @rtps.EntityId::new(b"\x00\x00\x2F", 0x04) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let graph_publication_id = match @rtps.EntityId::new(b"gph", 0x03) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let graph_subscription_id = match @rtps.EntityId::new(b"gph", 0x04) {
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
      45U,
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
  match participant.set_ros_node_identity("/demo", "moon_add_two_ints_client") {
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
      service,
      request_writer_id,
      response_reader_id,
      "RIHS01_000c5fd92d6b2e1a05949348f584d6d652adea1e92d691792011ac2273508302",
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
    discover_service(participant, service)
  }
  let (request_subscription, response_publication) = match
    discovered_endpoints {
    Ok(value) => value
    Err(message) => {
      println(message)
      participant.close()
      return
    }
  }
  let (discovery, user_socket) = participant.into_parts()
  discovery.close()
  let client = match
    @transport.RosServiceClient::new_with_shared_socket(
      service, user_socket, prefix, vendor_id, request_writer_id, request_subscription,
      response_reader_id, response_publication, 1L,
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let request_writer = @cdr.Writer::new()
  request_writer.write_i64(2L)
  request_writer.write_i64(3L)
  let request_identity = match client.request(request_writer.to_bytes()) {
    Ok(value) => value
    Err(message) => {
      println(message)
      client.close()
      return
    }
  }
  let (response_payload, _) = match client.receive_response(request_identity) {
    Ok(value) => value
    Err(message) => {
      println(message)
      client.close()
      return
    }
  }
  let response_reader = match @cdr.Reader::from_bytes(response_payload) {
    Ok(value) => value
    Err(message) => {
      println(message)
      client.close()
      return
    }
  }
  match response_reader.read_i64() {
    Ok(value) => println("AddTwoInts result: " + value.to_string())
    Err(message) => println(message)
  }
  client.close()
}
