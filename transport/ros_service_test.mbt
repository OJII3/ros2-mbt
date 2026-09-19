///|
fn service_test_prefix(values : Array[Byte]) -> @rtps.GuidPrefix {
  @rtps.GuidPrefix::from_array(values).unwrap()
}

///|
fn service_test_entity(key : Bytes, kind : Byte) -> @rtps.EntityId {
  @rtps.EntityId::new(key, kind).unwrap()
}

///|
fn service_test_endpoint_locator(socket : Udp) -> @rtps.Locator {
  socket.local_unicast_locator().unwrap()
}

///|
async test "reliable ROS service client and server correlate a response" {
  let client_prefix = service_test_prefix([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11])
  let server_prefix = service_test_prefix([11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0])
  let vendor_id = @rtps.VendorId::new(1, 15)
  let service = match
    @ros.RosService::new("/add_two_ints", "example_interfaces", "AddTwoInts") {
    Ok(value) => value
    Err(message) => fail(message)
  }

  let client_request_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let server_request_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let server_response_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let client_response_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))

  let client_request_id = service_test_entity(b"crq", 0xC2)
  let server_request_id = service_test_entity(b"srq", 0xC7)
  let server_response_id = service_test_entity(b"srs", 0xC2)
  let client_response_id = service_test_entity(b"crs", 0xC7)

  let client_request_publication = match
    service.request_to_sedp(
      @rtps.SedpEndpointKind::Publication,
      @rtps.Guid::new(client_prefix, client_request_id),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  client_request_publication.add_unicast_locator(
    service_test_endpoint_locator(client_request_socket),
  )
  let server_request_subscription = match
    service.request_to_sedp(
      @rtps.SedpEndpointKind::Subscription,
      @rtps.Guid::new(server_prefix, server_request_id),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  server_request_subscription.add_unicast_locator(
    service_test_endpoint_locator(server_request_socket),
  )
  let server_response_publication = match
    service.response_to_sedp(
      @rtps.SedpEndpointKind::Publication,
      @rtps.Guid::new(server_prefix, server_response_id),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  server_response_publication.add_unicast_locator(
    service_test_endpoint_locator(server_response_socket),
  )
  let client_response_subscription = match
    service.response_to_sedp(
      @rtps.SedpEndpointKind::Subscription,
      @rtps.Guid::new(client_prefix, client_response_id),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  client_response_subscription.add_unicast_locator(
    service_test_endpoint_locator(client_response_socket),
  )

  let client = match
    RosServiceClient::new(
      service, client_request_socket, client_response_socket, client_prefix, vendor_id,
      client_request_id, server_request_subscription, client_response_id, server_response_publication,
      1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let server = match
    RosServiceServer::new(
      service, server_request_socket, server_response_socket, server_prefix, vendor_id,
      server_request_id, client_request_publication, server_response_id, client_response_subscription,
      1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }

  let request_identity = match client.request(b"request") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (request, received_identity, request_source) = match
    server.receive_request() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(request, b"request")
  assert_eq(received_identity, request_identity)
  assert_eq(request_source.ip(), 0x7F000001U)
  match server.respond(request_identity, b"response") {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (response, response_source) = match
    client.receive_response(request_identity) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(response, b"response")
  assert_eq(response_source.ip(), 0x7F000001U)
  client.close()
  server.close()
}
