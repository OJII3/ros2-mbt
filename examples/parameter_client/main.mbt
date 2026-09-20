///|
async fn discover_get_parameters(
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
    _ => Err("discovery ended without matching GetParameters endpoints")
  }
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
  let service = match
    @ros.RosService::new(
      "/demo/moon_parameter_server/get_parameters", "rcl_interfaces", "GetParameters",
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let request_writer_id = @rtps.EntityId::new(b"\x00\x00\x36", 0x03).unwrap()
  let response_reader_id = @rtps.EntityId::new(b"\x00\x00\x37", 0x04).unwrap()
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
      service, request_writer_id, response_reader_id, "RIHS01_135a9e1c3d7cebef792f6687d7ddf99949b21a0bd9a320d863a9110a3f5cf4d6",
      "RIHS01_9fa773b46e39cc5d02db6224d8fd520bb9caeeffc2b27c96c1e59431baba9f2a",
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
    discover_get_parameters(participant, service)
  }
  let (request_subscription, response_publication) = match endpoints {
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
    .participant_vendor_id(response_publication.participant_guid()) {
    Some(vendor) if vendor == @rtps.VendorId::new(1, 16) =>
      @transport.RosServiceWireFormat::CycloneDdsPayload
    _ => @transport.RosServiceWireFormat::DdsRpcInline
  }
  let (discovery, user_socket) = participant.into_parts()
  discovery.close()
  let client = match
    @transport.RosServiceClient::new_with_shared_socket_and_wire_format(
      service, user_socket, prefix, vendor_id, request_writer_id, request_subscription,
      response_reader_id, response_publication, 1L, service_wire_format,
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let request_writer = @cdr.Writer::new()
  request_writer.write_u32(1U)
  request_writer.write_string("answer")
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
  let value_count = match response_reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => {
      println(message)
      client.close()
      return
    }
  }
  if value_count != 1 {
    println("GetParameters returned an unexpected number of values")
    client.close()
    return
  }
  let parameter_type = match response_reader.read_u8() {
    Ok(value) => value.to_int()
    Err(message) => {
      println(message)
      client.close()
      return
    }
  }
  match response_reader.read_bool() {
    Ok(_) => ()
    Err(message) => {
      println(message)
      client.close()
      return
    }
  }
  let parameter_value = match response_reader.read_i64() {
    Ok(value) => value
    Err(message) => {
      println(message)
      client.close()
      return
    }
  }
  if parameter_type != 2 {
    println("GetParameters returned a non-integer parameter")
    client.close()
    return
  }
  println("GetParameters answer: " + parameter_value.to_string())
  client.close()
}
