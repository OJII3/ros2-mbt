///|
async test "ROS participant owns discovery and user-data sockets" {
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let participant = match
    new_ddsi_participant(
      prefix,
      @rtps.VendorId::new(1, 15),
      0,
      0,
      0x7F000001U,
      60,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let discovery_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let user_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let node = match
    RosParticipant::from_sockets(
      discovery_socket, user_socket, participant, 0, 1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(
    node.participant().participant_guid(),
    participant.participant_guid(),
  )
  assert_eq(node.user_locator().kind(), @rtps.LOCATOR_KIND_UDP_V4)
  assert_eq(
    node.user_locator().port(),
    user_socket.local_addr().port().reinterpret_as_uint(),
  )
  assert_eq(node.graph().participant_count(), 0)
  node.close()
}

///|
async test "ROS participant rejects an invalid DDSI domain before binding" {
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_true(
    RosParticipant::new_ddsi(
      prefix,
      @rtps.VendorId::new(1, 15),
      0xFFFFFFFFU,
      0,
      0x7F000001U,
      60,
      1L,
  )
  is Err(_),
  )
}

///|
async test "ROS participant can send SPDP with DDSI multicast discovery" {
  let prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let participant = RosParticipant::new_ddsi(
    prefix,
    @rtps.VendorId::new(1, 15),
    0U,
    0U,
    0x7F000001U,
    60,
    1L,
  ).unwrap()
  participant.announce_spdp_once().unwrap()
  participant.close()
}

///|
async test "ROS participant drops graph sessions for removed endpoints" {
  let local_prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let remote_prefix = @rtps.GuidPrefix::from_array([
    11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
  ]).unwrap()
  let participant = new_ddsi_participant(
    local_prefix,
    @rtps.VendorId::new(1, 15),
    0,
    0,
    0x7F000001U,
    60,
  ).unwrap()
  let discovery_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let user_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let node = RosParticipant::from_sockets(
    discovery_socket, user_socket, participant, 0, 1L,
  ).unwrap()
  node.register_ros_discovery_info(
    @rtps.EntityId::new(b"gph", 0xC2).unwrap(),
    @rtps.EntityId::new(b"gph", 0xC7).unwrap(),
  ).unwrap()
  let remote_subscription = @ros.ros_discovery_info_to_sedp(
    @rtps.SedpEndpointKind::Subscription,
    @rtps.Guid::new(
      remote_prefix,
      @rtps.EntityId::new(b"sub", 0xC7).unwrap(),
    ),
  ).unwrap()
  remote_subscription.add_unicast_locator(node.user_locator())
  let remote_publication = @ros.ros_discovery_info_to_sedp(
    @rtps.SedpEndpointKind::Publication,
    @rtps.Guid::new(
      remote_prefix,
      @rtps.EntityId::new(b"pub", 0xC2).unwrap(),
    ),
  ).unwrap()
  remote_publication.add_unicast_locator(node.user_locator())
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let destination = node.discovery.session.socket.local_addr()
  let vendor_id = @rtps.VendorId::new(1, 15)
  let publication_data = remote_publication.to_data_submessage_with_vendor(
    vendor_id,
    @rtps.SedpEndpointKind::Publication.builtin_reader_id(),
    @rtps.SedpEndpointKind::Publication.builtin_writer_id(),
    1L,
  ).unwrap()
  sender.send_data(publication_data, remote_prefix, vendor_id, destination).unwrap()
  ignore(node.receive_discovery_once().unwrap())
  let subscription_data = remote_subscription.to_data_submessage_with_vendor(
    vendor_id,
    @rtps.SedpEndpointKind::Subscription.builtin_reader_id(),
    @rtps.SedpEndpointKind::Subscription.builtin_writer_id(),
    1L,
  ).unwrap()
  sender.send_data(subscription_data, remote_prefix, vendor_id, destination).unwrap()
  ignore(node.receive_discovery_once().unwrap())
  assert_eq(node.graph_publishers.length(), 1)
  assert_eq(node.graph_subscriptions.length(), 1)
  let publication_dispose = @rtps.DataSubmessage::new(
    @rtps.SedpEndpointKind::Publication.builtin_reader_id(),
    @rtps.SedpEndpointKind::Publication.builtin_writer_id(),
    2L,
    b"",
  ).with_key(remote_publication.endpoint_guid().to_bytes())
  .with_status_info(@rtps.STATUS_INFO_DISPOSED)
  sender.send_data(publication_dispose, remote_prefix, vendor_id, destination).unwrap()
  ignore(node.receive_discovery_once().unwrap())
  let subscription_dispose = @rtps.DataSubmessage::new(
    @rtps.SedpEndpointKind::Subscription.builtin_reader_id(),
    @rtps.SedpEndpointKind::Subscription.builtin_writer_id(),
    2L,
    b"",
  ).with_key(remote_subscription.endpoint_guid().to_bytes())
  .with_status_info(@rtps.STATUS_INFO_DISPOSED)
  sender.send_data(subscription_dispose, remote_prefix, vendor_id, destination).unwrap()
  ignore(node.receive_discovery_once().unwrap())
  assert_eq(node.graph_publishers.length(), 0)
  assert_eq(node.graph_subscriptions.length(), 0)
  let reappeared_publication = remote_publication.to_data_submessage_with_vendor(
    vendor_id,
    @rtps.SedpEndpointKind::Publication.builtin_reader_id(),
    @rtps.SedpEndpointKind::Publication.builtin_writer_id(),
    3L,
  ).unwrap()
  sender.send_data(
    reappeared_publication,
    remote_prefix,
    vendor_id,
    destination,
  ).unwrap()
  ignore(node.receive_discovery_once().unwrap())
  assert_eq(node.graph_subscriptions.length(), 1)
  node.close()
  sender.close()
}

///|
async test "ROS participant registers and retains local SEDP endpoints" {
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let participant = match
    new_ddsi_participant(
      prefix,
      @rtps.VendorId::new(1, 15),
      0,
      0,
      0x7F000001U,
      60,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let discovery_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let user_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let node = match
    RosParticipant::from_sockets(
      discovery_socket, user_socket, participant, 0, 1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match @rtps.EntityId::new(b"pub", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let topic = match
    @ros.RosTopic::new("/chatter", "std_msgs", "msg", "String") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match
    node.register_topic_endpoint(
      topic,
      @rtps.SedpEndpointKind::Publication,
      writer_id,
      @rtps.SedpQos::default(),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  assert_eq(node.local_endpoints().length(), 1)
  assert_eq(
    node.local_endpoints()[0].participant_guid(),
    participant.participant_guid(),
  )
  assert_eq(node.local_endpoints()[0].unicast_locators().length(), 1)
  let info = match node.participant_entities_info("/demo", "talker") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(info.node_entities_info_seq().length(), 1)
  assert_eq(info.node_entities_info_seq()[0].writer_gid_seq().length(), 1)
  assert_eq(info.node_entities_info_seq()[0].reader_gid_seq().length(), 0)
  let graph_publication_id = match @rtps.EntityId::new(b"gph", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let graph_subscription_id = match @rtps.EntityId::new(b"gph", 0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match
    node.register_ros_discovery_info(
      graph_publication_id, graph_subscription_id,
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  assert_eq(node.local_endpoints().length(), 3)
  let graph_qos = match node.local_endpoints()[1].qos() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(graph_qos.reliability(), @rtps.RELIABILITY_RELIABLE)
  let info_after_graph_registration = match
    node.participant_entities_info("/demo", "talker") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(
    info_after_graph_registration.node_entities_info_seq()[0]
    .writer_gid_seq()
    .length(),
    1,
  )
  assert_true(node.register_endpoint(node.local_endpoints()[0]) is Err(_))
  node.close()
}

///|
async test "ROS participant registers a topic endpoint with its type hash" {
  let prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let participant = new_ddsi_participant(
    prefix,
    @rtps.VendorId::new(1, 15),
    0,
    0,
    0x7F000001U,
    60,
  ).unwrap()
  let discovery_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let user_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let node = RosParticipant::from_sockets(
    discovery_socket, user_socket, participant, 0, 1L,
  ).unwrap()
  let topic = @ros.RosTopic::new(
    "/chatter", "std_msgs", "msg", "String",
  ).unwrap()
  let writer_id = @rtps.EntityId::new(b"pub", 0xC2).unwrap()
  let type_hash =
    "RIHS01_df668c740482bbd48fb39d76a70dfd4bd59db1288021743503259e948f6b1a18"
  match
    node.register_topic_endpoint_with_type_hash(
      topic,
      @rtps.SedpEndpointKind::Publication,
      writer_id,
      @rtps.SedpQos::default(),
      type_hash,
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  assert_eq(node.local_endpoints().length(), 1)
  let mut found = false
  for parameter in node.local_endpoints()[0].extra_parameters() {
    if parameter.id() == @rtps.PID_USER_DATA {
      found = true
      assert_eq(
        parameter,
        @rtps.qos_user_data_type_hash(type_hash),
      )
    }
  }
  assert_true(found)
  node.close()
}

///|
async test "ROS participant registers service client endpoints" {
  let prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let participant = new_ddsi_participant(
    prefix,
    @rtps.VendorId::new(1, 15),
    0,
    0,
    0x7F000001U,
    60,
  ).unwrap()
  let discovery_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let user_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let node = RosParticipant::from_sockets(
    discovery_socket, user_socket, participant, 0, 1L,
  ).unwrap()
  let service = @ros.RosService::new(
    "/add_two_ints", "example_interfaces", "AddTwoInts",
  ).unwrap()
  let request_writer_id = @rtps.EntityId::new(b"crq", 0xC2).unwrap()
  let response_reader_id = @rtps.EntityId::new(b"crs", 0xC7).unwrap()
  let request_hash = "RIHS01_request_hash"
  let response_hash = "RIHS01_response_hash"
  match
    node.register_service_client_with_type_hashes(
      service,
      request_writer_id,
      response_reader_id,
      request_hash,
      response_hash,
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  assert_eq(node.local_endpoints().length(), 2)
  assert_eq(node.local_endpoints()[0].topic_name(), "rq/add_two_intsRequest")
  assert_eq(
    node.local_endpoints()[0].kind(),
    @rtps.SedpEndpointKind::Publication,
  )
  assert_eq(node.local_endpoints()[1].topic_name(), "rr/add_two_intsReply")
  assert_eq(
    node.local_endpoints()[1].kind(),
    @rtps.SedpEndpointKind::Subscription,
  )
  let request_qos = node.local_endpoints()[0].qos().unwrap()
  assert_eq(request_qos.reliability(), @rtps.RELIABILITY_RELIABLE)
  assert_eq(node.local_endpoints()[0].type_hash(), Ok(Some(request_hash)))
  assert_eq(node.local_endpoints()[1].type_hash(), Ok(Some(response_hash)))
  let info = node.participant_entities_info("/demo", "client").unwrap()
  assert_eq(info.node_entities_info_seq()[0].writer_gid_seq().length(), 1)
  assert_eq(info.node_entities_info_seq()[0].reader_gid_seq().length(), 1)
  node.close()
}

///|
async test "ROS participants discover service endpoints before request reply" {
  let client_prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let server_prefix = @rtps.GuidPrefix::from_array([
    11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
  ]).unwrap()
  let service = @ros.RosService::new(
    "/add_two_ints", "example_interfaces", "AddTwoInts",
  ).unwrap()
  let participant_id = @rtps.EntityId::new(b"prt", 0xC1).unwrap()
  let spdp_reader = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
  ).unwrap()
  let spdp_writer = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
  ).unwrap()
  let client_discovery_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let server_discovery_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let client_user_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let server_user_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let client_discovery_locator = client_discovery_socket
    .local_unicast_locator()
    .unwrap()
  let server_discovery_locator = server_discovery_socket
    .local_unicast_locator()
    .unwrap()
  let client_data = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(client_prefix, participant_id),
    @rtps.VendorId::new(1, 15),
    0,
    60,
    0,
    0,
  )
  let server_data = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(server_prefix, participant_id),
    @rtps.VendorId::new(1, 15),
    0,
    60,
    0,
    0,
  )
  client_data.add_metatraffic_unicast(client_discovery_locator)
  server_data.add_metatraffic_unicast(server_discovery_locator)
  let client_session = DiscoverySession::new(
    client_discovery_socket,
    client_data,
    spdp_reader,
    spdp_writer,
    @socket.Addr::new(
      0x7F000001U,
      server_discovery_locator.port().reinterpret_as_int(),
    ),
    1L,
  ).unwrap()
  let server_session = DiscoverySession::new(
    server_discovery_socket,
    server_data,
    spdp_reader,
    spdp_writer,
    @socket.Addr::new(
      0x7F000001U,
      client_discovery_locator.port().reinterpret_as_int(),
    ),
    1L,
  ).unwrap()
  let client = RosParticipant::from_discovery_session(
    client_session, client_user_socket,
  ).unwrap()
  let server = RosParticipant::from_discovery_session(
    server_session, server_user_socket,
  ).unwrap()
  let client_request_id = @rtps.EntityId::new(b"crq", 0xC2).unwrap()
  let client_response_id = @rtps.EntityId::new(b"crs", 0xC7).unwrap()
  let server_request_id = @rtps.EntityId::new(b"srq", 0xC7).unwrap()
  let server_response_id = @rtps.EntityId::new(b"srs", 0xC2).unwrap()
  client
  .register_service_client(service, client_request_id, client_response_id)
  .unwrap()
  server
  .register_service_server(service, server_request_id, server_response_id)
  .unwrap()
  client.announce_spdp_once().unwrap()
  server.announce_spdp_once().unwrap()
  ignore(client.receive_discovery_once().unwrap())
  ignore(server.receive_discovery_once().unwrap())
  for _ in 0..<2 {
    ignore(client.receive_discovery_once().unwrap())
    ignore(server.receive_discovery_once().unwrap())
  }
  assert_eq(client.graph().publications().length(), 1)
  assert_eq(client.graph().subscriptions().length(), 1)
  assert_eq(server.graph().publications().length(), 1)
  assert_eq(server.graph().subscriptions().length(), 1)
  let client_request_publication = server.graph().publications()[0]
  let client_response_subscription = server.graph().subscriptions()[0]
  let server_request_subscription = client.graph().subscriptions()[0]
  let server_response_publication = client.graph().publications()[0]
  let (client_discovery, client_socket) = client.into_parts()
  let (server_discovery, server_socket) = server.into_parts()
  client_discovery.close()
  server_discovery.close()
  let client_facade = RosServiceClient::new_with_shared_socket(
    service,
    client_socket,
    client_prefix,
    @rtps.VendorId::new(1, 15),
    client_request_id,
    server_request_subscription,
    client_response_id,
    server_response_publication,
    1L,
  ).unwrap()
  let server_facade = RosServiceServer::new_with_shared_socket(
    service,
    server_socket,
    server_prefix,
    @rtps.VendorId::new(1, 15),
    server_request_id,
    client_request_publication,
    server_response_id,
    client_response_subscription,
    1L,
  ).unwrap()
  let request_identity = client_facade.request(b"discovered request").unwrap()
  let (request, received_identity, _) = server_facade.receive_request().unwrap()
  assert_eq(request, b"discovered request")
  assert_eq(received_identity, request_identity)
  server_facade.respond(request_identity, b"discovered response").unwrap()
  let (response, _) = client_facade.receive_response(request_identity).unwrap()
  assert_eq(response, b"discovered response")
  client_facade.close()
  server_facade.close()
}

///|
async test "ROS participant automatically announces endpoints after SPDP" {
  let publisher_prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let subscriber_prefix = match
    @rtps.GuidPrefix::from_array([11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let participant_id = match @rtps.EntityId::new(b"prt", 0xC1) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let spdp_reader = match
    @rtps.EntityId::new(
      b"\x00\x01\x00",
      @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let spdp_writer = match
    @rtps.EntityId::new(
      b"\x00\x01\x00",
      @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let publisher_discovery = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let subscriber_discovery = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let publisher_user = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let subscriber_user = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let publisher_data = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(publisher_prefix, participant_id),
    @rtps.VendorId::new(1, 15),
    0,
    60,
    0,
    0,
  )
  let subscriber_data = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(subscriber_prefix, participant_id),
    @rtps.VendorId::new(1, 15),
    0,
    60,
    0,
    0,
  )
  let publisher_locator = match publisher_discovery.local_unicast_locator() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let subscriber_locator = match subscriber_discovery.local_unicast_locator() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  publisher_data.add_metatraffic_unicast(publisher_locator)
  subscriber_data.add_metatraffic_unicast(subscriber_locator)
  let publisher_session = match
    DiscoverySession::new(
      publisher_discovery,
      publisher_data,
      spdp_reader,
      spdp_writer,
      @socket.Addr::new(
        0x7F000001U,
        subscriber_locator.port().reinterpret_as_int(),
      ),
      1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let subscriber_session = match
    DiscoverySession::new(
      subscriber_discovery,
      subscriber_data,
      spdp_reader,
      spdp_writer,
      @socket.Addr::new(
        0x7F000001U,
        publisher_locator.port().reinterpret_as_int(),
      ),
      1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let publisher = match
    RosParticipant::from_discovery_session(publisher_session, publisher_user) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let subscriber = match
    RosParticipant::from_discovery_session(subscriber_session, subscriber_user) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match @rtps.EntityId::new(b"pub", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let topic = match
    @ros.RosTopic::new("/chatter", "std_msgs", "msg", "String") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match
    publisher.register_topic_endpoint(
      topic,
      @rtps.SedpEndpointKind::Publication,
      writer_id,
      @rtps.SedpQos::default(),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let graph_publication_id = match @rtps.EntityId::new(b"gph", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let graph_subscription_id = match @rtps.EntityId::new(b"gph", 0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match
    publisher.register_ros_discovery_info(
      graph_publication_id, graph_subscription_id,
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match
    subscriber.register_ros_discovery_info(
      graph_publication_id, graph_subscription_id,
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let info = match publisher.participant_entities_info("/demo", "talker") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_true(publisher.publish_ros_discovery_info(info) is Err(_))
  match publisher.announce_spdp_once() {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match subscriber.announce_spdp_once() {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match publisher.receive_discovery_once() {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match subscriber.receive_discovery_once() {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  for _ in 0..<3 {
    match subscriber.receive_discovery_once() {
      Ok(_) => ()
      Err(message) => fail(message)
    }
  }
  for _ in 0..<2 {
    match publisher.receive_discovery_once() {
      Ok(_) => ()
      Err(message) => fail(message)
    }
  }
  assert_eq(subscriber.graph().participant_count(), 1)
  assert_eq(subscriber.graph().publication_count(), 2)
  assert_eq(publisher.ros_discovery_publisher_count(), 1)
  assert_eq(publisher.ros_discovery_subscription_count(), 1)
  assert_eq(subscriber.ros_discovery_publisher_count(), 1)
  assert_eq(subscriber.ros_discovery_subscription_count(), 1)
  let (decoded, _) = match subscriber.receive_ros_discovery_info(0) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (heartbeat, _) = match subscriber.receive_ros_discovery_heartbeat(0) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (acknack, _) = match publisher.receive_ros_discovery_acknack(0) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.to_cdr_bytes(), info.to_cdr_bytes())
  assert_eq(heartbeat.last_sequence_number(), 1L)
  assert_eq(acknack.bitmap(), [0U])
  assert_eq(subscriber.graph().ros_participant_count(), 1)
  let late_writer_id = @rtps.EntityId::new(b"lat", 0xC2).unwrap()
  let late_topic = @ros.RosTopic::new(
    "/late_topic", "std_msgs", "msg", "String",
  ).unwrap()
  publisher
    .register_topic_endpoint(
      late_topic,
      @rtps.SedpEndpointKind::Publication,
      late_writer_id,
      @rtps.SedpQos::default(),
    )
    .unwrap()
  assert_true(publisher.latest_graph_info is None)
  publisher.close()
  subscriber.close()
}
