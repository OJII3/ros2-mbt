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

  let client_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let server_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let client_address = client_socket.local_addr()
  let ack_sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))

  let client_request_id = service_test_entity(b"crq", 0xC2)
  let server_request_id = service_test_entity(b"srq", 0xC7)
  let server_response_id = service_test_entity(b"srs", 0xC2)
  let client_response_id = service_test_entity(b"crs", 0xC7)

  let client_request_guid = @rtps.Guid::new(client_prefix, client_request_id)
  let client_response_guid = @rtps.Guid::new(client_prefix, client_response_id)
  let server_request_guid = @rtps.Guid::new(server_prefix, server_request_id)
  let server_response_guid = @rtps.Guid::new(server_prefix, server_response_id)
  let client_request_publication = match
    service.request_to_sedp_with_related_endpoint(
      @rtps.SedpEndpointKind::Publication,
      client_request_guid,
      client_response_guid,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  client_request_publication.add_unicast_locator(
    service_test_endpoint_locator(client_socket),
  )
  let server_request_subscription = match
    service.request_to_sedp_with_related_endpoint(
      @rtps.SedpEndpointKind::Subscription,
      server_request_guid,
      server_response_guid,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  server_request_subscription.add_unicast_locator(
    service_test_endpoint_locator(server_socket),
  )
  let server_response_publication = match
    service.response_to_sedp_with_related_endpoint(
      @rtps.SedpEndpointKind::Publication,
      server_response_guid,
      server_request_guid,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  server_response_publication.add_unicast_locator(
    service_test_endpoint_locator(server_socket),
  )
  let client_response_subscription = match
    service.response_to_sedp_with_related_endpoint(
      @rtps.SedpEndpointKind::Subscription,
      client_response_guid,
      client_request_guid,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  client_response_subscription.add_unicast_locator(
    service_test_endpoint_locator(client_socket),
  )

  let client = match
    RosServiceClient::new_with_shared_socket(
      service, client_socket, client_prefix, vendor_id, client_request_id, server_request_subscription,
      client_response_id, server_response_publication, 1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let server = match
    RosServiceServer::new_with_shared_socket(
      service, server_socket, server_prefix, vendor_id, server_request_id, client_request_publication,
      server_response_id, client_response_subscription, 1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }

  let request_identity = match client.request(b"request") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let expected_request_identity = @rtps.SampleIdentity::new(
    @rtps.Guid::new(client_prefix, client_response_id),
    1L,
  ).unwrap()
  assert_eq(request_identity, expected_request_identity)
  let (request, received_identity, request_source) = match
    server.receive_request() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(request, b"request")
  assert_eq(received_identity, request_identity)
  assert_eq(request_source.ip(), 0x7F000001U)
  let request_acknack = @rtps.AckNackSubmessage::new(
    server_request_id,
    client_request_id,
    1L,
    1U,
    [0x80000000U],
    1U,
  ).unwrap()
  match
    ack_sender.send_acknack(
      request_acknack,
      server_prefix,
      vendor_id,
      client_address,
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  @async.sleep(10)
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
  let (retransmitted_request, _, _) = match server.receive_request() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(retransmitted_request, b"request")
  let second_request_identity = match client.request(b"request-2") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (second_request, second_received_identity, _) = match
    server.receive_request() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(second_request, b"request-2")
  assert_eq(second_received_identity, second_request_identity)
  match server.respond(second_request_identity, b"response-2") {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (second_response, _) = match
    client.receive_response(second_request_identity) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(second_response, b"response-2")
  client.close()
  server.close()
  ack_sender.close()
}

///|
async test "ROS action SendGoal endpoint uses service request reply transport" {
  let client_prefix = service_test_prefix([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11])
  let server_prefix = service_test_prefix([11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0])
  let vendor_id = @rtps.VendorId::new(1, 15)
  let action = @ros.RosAction::new(
    "/fibonacci",
    "example_interfaces",
    "Fibonacci",
  ).unwrap()
  let service = action.send_goal_service()
  let client_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let server_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let client_address = client_socket.local_addr()
  let ack_sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let client_request_id = service_test_entity(b"crq", 0xC2)
  let client_response_id = service_test_entity(b"crs", 0xC7)
  let server_request_id = service_test_entity(b"srq", 0xC7)
  let server_response_id = service_test_entity(b"srs", 0xC2)
  let client_request_guid = @rtps.Guid::new(client_prefix, client_request_id)
  let client_response_guid = @rtps.Guid::new(client_prefix, client_response_id)
  let server_request_guid = @rtps.Guid::new(server_prefix, server_request_id)
  let server_response_guid = @rtps.Guid::new(server_prefix, server_response_id)
  let client_request = service
    .request_to_sedp_with_related_endpoint(
      @rtps.SedpEndpointKind::Publication,
      client_request_guid,
      client_response_guid,
    )
    .unwrap()
  client_request.add_unicast_locator(service_test_endpoint_locator(client_socket))
  let server_request = service
    .request_to_sedp_with_related_endpoint(
      @rtps.SedpEndpointKind::Subscription,
      server_request_guid,
      server_response_guid,
    )
    .unwrap()
  server_request.add_unicast_locator(service_test_endpoint_locator(server_socket))
  let server_response = service
    .response_to_sedp_with_related_endpoint(
      @rtps.SedpEndpointKind::Publication,
      server_response_guid,
      server_request_guid,
    )
    .unwrap()
  server_response.add_unicast_locator(service_test_endpoint_locator(server_socket))
  let client_response = service
    .response_to_sedp_with_related_endpoint(
      @rtps.SedpEndpointKind::Subscription,
      client_response_guid,
      client_request_guid,
    )
    .unwrap()
  client_response.add_unicast_locator(service_test_endpoint_locator(client_socket))
  let client = RosServiceClient::new_with_shared_socket(
    service,
    client_socket,
    client_prefix,
    vendor_id,
    client_request_id,
    server_request,
    client_response_id,
    server_response,
    1L,
  ).unwrap()
  let server = RosServiceServer::new_with_shared_socket(
    service,
    server_socket,
    server_prefix,
    vendor_id,
    server_request_id,
    client_request,
    server_response_id,
    client_response,
    1L,
  ).unwrap()
  let request_identity = client.request(b"serialized Fibonacci goal").unwrap()
  let (request, received_identity, _) = server.receive_request().unwrap()
  assert_eq(request, b"serialized Fibonacci goal")
  assert_eq(received_identity, request_identity)
  let request_acknack = @rtps.AckNackSubmessage::new(
    server_request_id,
    client_request_id,
    1L,
    1U,
    [0x80000000U],
    1U,
  ).unwrap()
  ack_sender.send_acknack(
    request_acknack,
    server_prefix,
    vendor_id,
    client_address,
  ).unwrap()
  @async.sleep(10)
  server.respond(request_identity, b"accepted goal response").unwrap()
  let (response, _) = client.receive_response(request_identity).unwrap()
  assert_eq(response, b"accepted goal response")
  client.close()
  server.close()
  ack_sender.close()
}

///|
async test "ROS service rejects mismatched related endpoint metadata" {
  let prefix = service_test_prefix([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11])
  let service = @ros.RosService::new(
    "/add_two_ints", "example_interfaces", "AddTwoInts",
  ).unwrap()
  let request_id = service_test_entity(b"req", 0xC2)
  let response_id = service_test_entity(b"res", 0xC7)
  let wrong_response_id = service_test_entity(b"bad", 0xC7)
  let request_guid = @rtps.Guid::new(prefix, request_id)
  let response_guid = @rtps.Guid::new(prefix, response_id)
  let wrong_response_guid = @rtps.Guid::new(prefix, wrong_response_id)
  let request = service
    .request_to_sedp_with_related_endpoint(
      @rtps.SedpEndpointKind::Subscription,
      request_guid,
      wrong_response_guid,
    )
    .unwrap()
  let response = service
    .response_to_sedp_with_related_endpoint(
      @rtps.SedpEndpointKind::Publication,
      response_guid,
      request_guid,
    )
    .unwrap()
  let request_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let response_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  assert_true(
    RosServiceClient::new(
      service,
      request_socket,
      response_socket,
      prefix,
      @rtps.VendorId::new(1, 15),
      service_test_entity(b"cli", 0xC2),
      request,
      service_test_entity(b"cl2", 0xC7),
      response,
      1L,
    )
    is Err(_),
  )
  request_socket.close()
  response_socket.close()
}
