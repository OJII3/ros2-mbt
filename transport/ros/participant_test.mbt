///|
async test "ROS participant owns discovery and user-data sockets" {
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let participant = match
    @wire.new_ddsi_participant(
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
  let discovery_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer discovery_socket.close()
  let user_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer user_socket.close()
  let node = match
    @ros.RosParticipant::from_sockets(
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
async test "ROS participant disposal removes its SEDP endpoints and SPDP participant" {
  let local_prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let remote_prefix = @rtps.GuidPrefix::from_array([
    11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
  ]).unwrap()
  let vendor_id = @rtps.VendorId::new(1, 15)
  let participant_id = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
  ).unwrap()
  let spdp_reader = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
  ).unwrap()
  let local_participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(local_prefix, participant_id),
    vendor_id,
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR,
  )
  let remote_receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer remote_receiver.close()
  let remote_sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer remote_sender.close()
  let discovery_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer discovery_socket.close()
  let user_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer user_socket.close()
  let remote_participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(remote_prefix, participant_id),
    vendor_id,
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR,
  )
  remote_participant.add_metatraffic_unicast(
    remote_receiver.local_unicast_locator().unwrap(),
  )
  let session = @discovery.DiscoverySession::new(
    discovery_socket,
    local_participant,
    spdp_reader,
    participant_id,
    remote_sender.local_addr(),
    1L,
  ).unwrap()
  let node = @ros.RosParticipant::from_discovery_session(session, user_socket).unwrap()
  remote_sender
  .send_data(
    remote_participant.to_data_submessage(spdp_reader, participant_id, 1L),
    remote_prefix,
    vendor_id,
    node.discovery.session.socket.local_addr(),
  )
  .unwrap()
  match test_receive(() => node.receive_discovery_once()).unwrap().1 {
    Participant(_) => ()
    _ => fail("expected the remote SPDP participant")
  }
  let endpoint = @rtps.SedpEndpointData::new(
    Publication,
    @rtps.Guid::new(
      local_prefix,
      @rtps.EntityId::new(b"pub", @rtps.ENTITYID_SEDP_PUBLICATIONS_WRITER).unwrap(),
    ),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  endpoint.add_unicast_locator(node.user_locator())
  node.register_endpoint(endpoint).unwrap()
  match test_receive(() => remote_receiver.receive_discovery()).unwrap().0 {
    Publication(publication) =>
      assert_eq(publication.topic_name(), "rt/chatter")
    _ => fail("expected the SEDP publication announcement")
  }
  ignore(test_receive(() => remote_receiver.receive_heartbeat()).unwrap())
  node.dispose_and_close().unwrap()
  match test_receive(() => remote_receiver.receive_discovery()).unwrap().0 {
    EndpointRemoved(kind, endpoint_guid) => {
      assert_eq(kind, Publication)
      assert_eq(endpoint_guid, endpoint.endpoint_guid())
    }
    _ => fail("expected the SEDP endpoint removal")
  }
  ignore(test_receive(() => remote_receiver.receive_heartbeat()).unwrap())
  match test_receive(() => remote_sender.receive_discovery()).unwrap().0 {
    ParticipantRemoved(participant_guid) =>
      assert_eq(participant_guid, local_participant.participant_guid())
    _ => fail("expected the SPDP participant removal")
  }
  remote_receiver.close()
  remote_sender.close()
}

///|
async test "ROS participant rejects an invalid DDSI domain before binding" {
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_true(
    @ros.RosParticipant::new_ddsi(
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
  let participant = @ros.RosParticipant::new_ddsi(
    prefix,
    @rtps.VendorId::new(1, 15),
    0U,
    0U,
    0x7F000001U,
    60,
    1L,
    multicast_interface=0x7F000001U,
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
  let participant = @wire.new_ddsi_participant(
    local_prefix,
    @rtps.VendorId::new(1, 15),
    0,
    0,
    0x7F000001U,
    60,
  ).unwrap()
  let discovery_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer discovery_socket.close()
  let user_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer user_socket.close()
  let node = @ros.RosParticipant::from_sockets(
    discovery_socket, user_socket, participant, 0, 1L,
  ).unwrap()
  node
  .register_ros_discovery_info(
    @rtps.EntityId::new(b"gph", 0xC2).unwrap(),
    @rtps.EntityId::new(b"gph", 0xC7).unwrap(),
  )
  .unwrap()
  let remote_subscription = @ros_types.ros_discovery_info_to_sedp(
    Subscription,
    @rtps.Guid::new(remote_prefix, @rtps.EntityId::new(b"sub", 0xC7).unwrap()),
  ).unwrap()
  remote_subscription.add_unicast_locator(node.user_locator())
  let remote_publication = @ros_types.ros_discovery_info_to_sedp(
    Publication,
    @rtps.Guid::new(remote_prefix, @rtps.EntityId::new(b"pub", 0xC2).unwrap()),
  ).unwrap()
  remote_publication.add_unicast_locator(node.user_locator())
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer sender.close()
  let destination = node.discovery.session.socket.local_addr()
  let vendor_id = @rtps.VendorId::new(1, 15)
  let publication_data = remote_publication
    .to_data_submessage_with_vendor(
      vendor_id,
      @rtps.SedpEndpointKind::Publication.builtin_reader_id(),
      @rtps.SedpEndpointKind::Publication.builtin_writer_id(),
      1L,
    )
    .unwrap()
  sender
  .send_data(publication_data, remote_prefix, vendor_id, destination)
  .unwrap()
  ignore(test_receive(() => node.receive_discovery_once()).unwrap())
  let subscription_data = remote_subscription
    .to_data_submessage_with_vendor(
      vendor_id,
      @rtps.SedpEndpointKind::Subscription.builtin_reader_id(),
      @rtps.SedpEndpointKind::Subscription.builtin_writer_id(),
      1L,
    )
    .unwrap()
  sender
  .send_data(subscription_data, remote_prefix, vendor_id, destination)
  .unwrap()
  ignore(test_receive(() => node.receive_discovery_once()).unwrap())
  assert_eq(node.ros_graph.graph_publishers.length(), 1)
  assert_eq(node.ros_graph.graph_subscriptions.length(), 1)
  let publication_dispose = @rtps.DataSubmessage::new(
      @rtps.SedpEndpointKind::Publication.builtin_reader_id(),
      @rtps.SedpEndpointKind::Publication.builtin_writer_id(),
      2L,
      b"",
    )
    .with_key(remote_publication.endpoint_guid().to_bytes())
    .with_status_info(@rtps.STATUS_INFO_DISPOSED)
  sender
  .send_data(publication_dispose, remote_prefix, vendor_id, destination)
  .unwrap()
  ignore(test_receive(() => node.receive_discovery_once()).unwrap())
  let subscription_dispose = @rtps.DataSubmessage::new(
      @rtps.SedpEndpointKind::Subscription.builtin_reader_id(),
      @rtps.SedpEndpointKind::Subscription.builtin_writer_id(),
      2L,
      b"",
    )
    .with_key(remote_subscription.endpoint_guid().to_bytes())
    .with_status_info(@rtps.STATUS_INFO_DISPOSED)
  sender
  .send_data(subscription_dispose, remote_prefix, vendor_id, destination)
  .unwrap()
  ignore(test_receive(() => node.receive_discovery_once()).unwrap())
  assert_eq(node.ros_graph.graph_publishers.length(), 0)
  assert_eq(node.ros_graph.graph_subscriptions.length(), 0)
  let reappeared_publication = remote_publication
    .to_data_submessage_with_vendor(
      vendor_id,
      @rtps.SedpEndpointKind::Publication.builtin_reader_id(),
      @rtps.SedpEndpointKind::Publication.builtin_writer_id(),
      3L,
    )
    .unwrap()
  sender
  .send_data(reappeared_publication, remote_prefix, vendor_id, destination)
  .unwrap()
  ignore(test_receive(() => node.receive_discovery_once()).unwrap())
  assert_eq(node.ros_graph.graph_subscriptions.length(), 1)
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
    @wire.new_ddsi_participant(
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
  let discovery_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer discovery_socket.close()
  let user_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer user_socket.close()
  let node = match
    @ros.RosParticipant::from_sockets(
      discovery_socket, user_socket, participant, 0, 1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match node.set_ros_node_identity("/demo", "talker") {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  assert_true(node.ros_graph.latest_graph_info is Some(_))
  let writer_id = match @rtps.EntityId::new(b"pub", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let topic = match
    @ros_types.RosTopic::new("/chatter", "std_msgs", "msg", "String") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match
    node.register_topic_endpoint(
      topic,
      Publication,
      writer_id,
      @rtps.SedpQos::default(),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  assert_eq(node.local_endpoints().length(), 1)
  let automatic_info = match node.ros_graph.latest_graph_info {
    Some(value) => value
    None => fail("automatic ROS graph information was not cached")
  }
  assert_eq(
    automatic_info.node_entities_info_seq()[0].writer_gid_seq().length(),
    1,
  )
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
  match node.unregister_endpoint(@rtps.Guid::new(prefix, writer_id)) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  assert_eq(node.local_endpoints().length(), 2)
  assert_true(
    node.unregister_endpoint(@rtps.Guid::new(prefix, writer_id)) is Err(_),
  )
  let cleared_info = match node.ros_graph.latest_graph_info {
    Some(value) => value
    None => fail("automatic ROS graph information was not refreshed")
  }
  assert_eq(
    cleared_info.node_entities_info_seq()[0].writer_gid_seq().length(),
    0,
  )
  node.close()
}

///|
async test "ROS participant registers a topic endpoint with its type hash" {
  let prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let participant = @wire.new_ddsi_participant(
    prefix,
    @rtps.VendorId::new(1, 15),
    0,
    0,
    0x7F000001U,
    60,
  ).unwrap()
  let discovery_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer discovery_socket.close()
  let user_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer user_socket.close()
  let node = @ros.RosParticipant::from_sockets(
    discovery_socket, user_socket, participant, 0, 1L,
  ).unwrap()
  let topic = @ros_types.RosTopic::new("/chatter", "std_msgs", "msg", "String").unwrap()
  let writer_id = @rtps.EntityId::new(b"pub", 0xC2).unwrap()
  let type_hash = "RIHS01_df668c740482bbd48fb39d76a70dfd4bd59db1288021743503259e948f6b1a18"
  match
    node.register_topic_endpoint_with_type_hash(
      topic,
      Publication,
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
      assert_eq(parameter, @rtps.qos_user_data_type_hash(type_hash))
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
  let participant = @wire.new_ddsi_participant(
    prefix,
    @rtps.VendorId::new(1, 15),
    0,
    0,
    0x7F000001U,
    60,
  ).unwrap()
  let discovery_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer discovery_socket.close()
  let user_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer user_socket.close()
  let node = @ros.RosParticipant::from_sockets(
    discovery_socket, user_socket, participant, 0, 1L,
  ).unwrap()
  let service = @ros_types.RosService::new(
    "/add_two_ints", "example_interfaces", "AddTwoInts",
  ).unwrap()
  let request_writer_id = @rtps.EntityId::new(b"crq", 0xC2).unwrap()
  let response_reader_id = @rtps.EntityId::new(b"crs", 0xC7).unwrap()
  let request_hash = "RIHS01_request_hash"
  let response_hash = "RIHS01_response_hash"
  match
    node.register_service_client_with_type_hashes(
      service, request_writer_id, response_reader_id, request_hash, response_hash,
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  assert_eq(node.local_endpoints().length(), 2)
  assert_eq(node.local_endpoints()[0].topic_name(), "rq/add_two_intsRequest")
  assert_eq(node.local_endpoints()[0].kind(), Publication)
  assert_eq(node.local_endpoints()[1].topic_name(), "rr/add_two_intsReply")
  assert_eq(node.local_endpoints()[1].kind(), Subscription)
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
  let service = @ros_types.RosService::new(
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
  let client_discovery_socket = @wire.Udp::bind(
    @socket.Addr::new(0x7F000001U, 0),
  ).unwrap()
  defer client_discovery_socket.close()
  let server_discovery_socket = @wire.Udp::bind(
    @socket.Addr::new(0x7F000001U, 0),
  ).unwrap()
  defer server_discovery_socket.close()
  let client_user_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer client_user_socket.close()
  let server_user_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer server_user_socket.close()
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
  let client_session = @discovery.DiscoverySession::new(
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
  let server_session = @discovery.DiscoverySession::new(
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
  let client = @ros.RosParticipant::from_discovery_session(
    client_session, client_user_socket,
  ).unwrap()
  let server = @ros.RosParticipant::from_discovery_session(
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
  ignore(test_receive(() => client.receive_discovery_once()).unwrap())
  ignore(test_receive(() => server.receive_discovery_once()).unwrap())
  for _ in 0..<2 {
    ignore(test_receive(() => client.receive_discovery_once()).unwrap())
    ignore(test_receive(() => server.receive_discovery_once()).unwrap())
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
  let client_facade = @ros.RosServiceClient::new_with_shared_socket(
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
  let server_facade = @ros.RosServiceServer::new_with_shared_socket(
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
  // The socket owner dispatches the request before the server consumes it.
  let (message, source) = test_receive(() => server_socket.receive_message()).unwrap()
  server_facade.handle_message(message, source).unwrap()
  let (request, received_identity, _) = server_facade
    .take_request()
    .unwrap()
    .unwrap()
  assert_true(server_facade.take_request().unwrap() is None)
  assert_eq(request, b"discovered request")
  assert_eq(received_identity, request_identity)
  server_facade.respond(request_identity, b"discovered response").unwrap()
  let (response, _) = test_receive(() => {
    client_facade.receive_response(request_identity)
  }).unwrap()
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
  let publisher_discovery = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer publisher_discovery.close()
  let subscriber_discovery = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer subscriber_discovery.close()
  let publisher_user = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer publisher_user.close()
  let subscriber_user = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer subscriber_user.close()
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
    @discovery.DiscoverySession::new(
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
    @discovery.DiscoverySession::new(
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
    @ros.RosParticipant::from_discovery_session(
      publisher_session, publisher_user,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let subscriber = match
    @ros.RosParticipant::from_discovery_session(
      subscriber_session, subscriber_user,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match publisher.set_ros_node_identity("/demo", "talker") {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let writer_id = match @rtps.EntityId::new(b"pub", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let topic = match
    @ros_types.RosTopic::new("/chatter", "std_msgs", "msg", "String") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match
    publisher.register_topic_endpoint(
      topic,
      Publication,
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
  assert_true(publisher.ros_graph.latest_graph_info is Some(_))
  match publisher.announce_spdp_once() {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match subscriber.announce_spdp_once() {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match test_receive(() => publisher.receive_discovery_once()) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match test_receive(() => subscriber.receive_discovery_once()) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  for _ in 0..<2 {
    match test_receive(() => publisher.receive_discovery_once()) {
      Ok(_) => ()
      Err(message) => fail(message)
    }
  }
  assert_eq(publisher.graph().publication_count(), 1)
  assert_eq(publisher.graph().subscription_count(), 1)
  assert_eq(publisher.ros_discovery_publisher_count(), 0)
  assert_eq(publisher.ros_discovery_subscription_count(), 0)
  match
    publisher.register_ros_discovery_info(
      graph_publication_id, graph_subscription_id,
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  for _ in 0..<3 {
    match test_receive(() => subscriber.receive_discovery_once()) {
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
  let (decoded, _) = match
    test_receive(() => subscriber.receive_ros_discovery_info(0)) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (heartbeat, _) = match
    test_receive(() => subscriber.receive_ros_discovery_heartbeat(0)) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (acknack, _) = match
    test_receive(() => publisher.receive_ros_discovery_acknack(0)) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.to_cdr_bytes(), info.to_cdr_bytes())
  assert_eq(heartbeat.last_sequence_number(), 1L)
  assert_eq(acknack.bitmap_base(), 2L)
  assert_eq(acknack.num_bits(), 0U)
  assert_eq(acknack.bitmap(), [])
  assert_eq(subscriber.graph().ros_participant_count(), 1)
  let late_writer_id = @rtps.EntityId::new(b"lat", 0xC2).unwrap()
  let late_topic = @ros_types.RosTopic::new(
    "/late_topic", "std_msgs", "msg", "String",
  ).unwrap()
  publisher
  .register_topic_endpoint(
    late_topic,
    Publication,
    late_writer_id,
    @rtps.SedpQos::default(),
  )
  .unwrap()
  match test_receive(() => subscriber.receive_discovery_once()) {
    Ok((_, Publication(publication))) =>
      assert_eq(publication.topic_name(), "rt/late_topic")
    Ok(_) => fail("expected the late SEDP publication")
    Err(message) => fail(message)
  }
  let refreshed_info = match publisher.ros_graph.latest_graph_info {
    Some(value) => value
    None => fail("automatic ROS graph information was not refreshed")
  }
  assert_eq(
    refreshed_info.node_entities_info_seq()[0].writer_gid_seq().length(),
    2,
  )
  let (decoded_refreshed, _) = match
    test_receive(() => subscriber.receive_ros_discovery_info(0)) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(
    decoded_refreshed.node_entities_info_seq()[0].writer_gid_seq().length(),
    2,
  )
  publisher
  .unregister_endpoint(
    @rtps.Guid::new(
      publisher.participant().participant_guid().prefix(),
      late_writer_id,
    ),
  )
  .unwrap()
  let (decoded_removed, _) = match
    test_receive(() => subscriber.receive_ros_discovery_info(0)) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(
    decoded_removed.node_entities_info_seq()[0].writer_gid_seq().length(),
    1,
  )
  publisher.close()
  subscriber.close()
}

///|
async fn participant_history_sequences(socket : @wire.Udp) -> Array[Int64] {
  let sequences : Array[Int64] = []
  while sequences.length() < 2 {
    let (message, _) = @async.with_timeout(1000, async fn() {
      socket.receive_message().unwrap()
    })
    for submessage in message.submessages() {
      if submessage.id() == Data {
        sequences.push(
          @rtps.DataSubmessage::from_submessage(submessage)
          .unwrap()
          .writer_sequence_number(),
        )
      }
    }
  }
  sequences
}

///|
async test "SPDP refresh reuses registered history and new or rediscovered peers receive all endpoints" {
  let discovery_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  let user_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  let remote1_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer remote1_socket.close()
  let remote2_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer remote2_socket.close()
  let participant_id = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
  ).unwrap()
  let reader_id = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
  ).unwrap()
  let participants : Array[@rtps.SpdpParticipantData] = []
  for id in 0..<3 {
    participants.push(
      @rtps.SpdpParticipantData::new(
        @rtps.Guid::new(
          @rtps.GuidPrefix::from_array([
            id.to_byte(),
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
          ]).unwrap(),
          participant_id,
        ),
        @rtps.VendorId::new(1, 15),
        0,
        60,
        0U,
        3U,
      ),
    )
  }
  participants[1].add_metatraffic_unicast(
    remote1_socket.local_unicast_locator().unwrap(),
  )
  participants[2].add_metatraffic_unicast(
    remote2_socket.local_unicast_locator().unwrap(),
  )
  let session = @discovery.DiscoverySession::new(
    discovery_socket,
    participants[0],
    reader_id,
    participant_id,
    remote1_socket.local_addr(),
    1L,
  ).unwrap()
  let node = @ros.RosParticipant::from_discovery_session(session, user_socket).unwrap()
  defer node.close()
  for id in 1..<3 {
    node
    .register_endpoint(
      @rtps.SedpEndpointData::new(
        Publication,
        @rtps.Guid::new(
          participants[0].participant_guid().prefix(),
          @rtps.EntityId::new(Bytes::from_array([id.to_byte(), 0, 0]), 0x02).unwrap(),
        ),
        "rt/chatter",
        "std_msgs::msg::dds_::String_",
      ).unwrap(),
    )
    .unwrap()
  }
  assert_eq(node.discovery.next_sedp_sequence_number(Publication), 3L)
  for (peer_index, socket) in [(1, remote1_socket), (2, remote2_socket)] {
    let remote = participants[peer_index]
    socket
    .send_data(
      remote.to_data_submessage(reader_id, participant_id, 1L),
      remote.participant_guid().prefix(),
      remote.vendor_id(),
      discovery_socket.local_addr(),
    )
    .unwrap()
    assert_true(
      test_receive(() => node.receive_discovery_once()).unwrap().1
      is Participant(_),
    )
    assert_eq(participant_history_sequences(socket), [1L, 2L])
    assert_eq(node.discovery.next_sedp_sequence_number(Publication), 3L)
  }
  let remote = participants[1]
  for sequence in 2..<12 {
    remote1_socket
    .send_data(
      remote.to_data_submessage(reader_id, participant_id, sequence.to_int64()),
      remote.participant_guid().prefix(),
      remote.vendor_id(),
      discovery_socket.local_addr(),
    )
    .unwrap()
    assert_true(
      test_receive(() => node.receive_discovery_once()).unwrap().1
      is Participant(_),
    )
    assert_eq(node.discovery.next_sedp_sequence_number(Publication), 3L)
  }
  remote1_socket
  .send_data(
    remote.to_dispose_data_submessage(reader_id, participant_id, 12L),
    remote.participant_guid().prefix(),
    remote.vendor_id(),
    discovery_socket.local_addr(),
  )
  .unwrap()
  assert_true(
    test_receive(() => node.receive_discovery_once()).unwrap().1
    is ParticipantRemoved(_),
  )
  remote1_socket
  .send_data(
    remote.to_data_submessage(reader_id, participant_id, 13L),
    remote.participant_guid().prefix(),
    remote.vendor_id(),
    discovery_socket.local_addr(),
  )
  .unwrap()
  assert_true(
    test_receive(() => node.receive_discovery_once()).unwrap().1
    is Participant(_),
  )
  assert_eq(participant_history_sequences(remote1_socket), [1L, 2L])
  assert_eq(node.discovery.next_sedp_sequence_number(Publication), 3L)
}

///|
async test "endpoint registration reserves before async sending and separates admission from send failures" {
  let prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let data = @wire.new_ddsi_participant(
    prefix,
    @rtps.VendorId::new(1, 15),
    0U,
    0U,
    0x7F000001U,
    60,
  ).unwrap()
  let discovery_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  let user_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  let node = @ros.RosParticipant::from_sockets(
    discovery_socket, user_socket, data, 0U, 1L,
  ).unwrap()
  defer node.close()
  let endpoint = @rtps.SedpEndpointData::new(
    Publication,
    @rtps.Guid::new(prefix, @rtps.EntityId::new(b"pub", 0x02).unwrap()),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  node.discovery.session.send_lock.acquire()
  @async.with_task_group() <| group => {
    let registering = group.spawn(() => node.register_endpoint(endpoint))
    @async.sleep(1)
    assert_eq(node.local_endpoints().length(), 1)
    assert_eq(node.discovery.next_sedp_sequence_number(Publication), 2L)
    // The first registration is still waiting to flush, so this is concurrent.
    assert_true(node.register_endpoint(endpoint) is Err(_))
    assert_eq(node.local_endpoints().length(), 1)
    node.discovery.session.send_lock.release()
    assert_true(registering.wait() is Ok(_))
  }
  let remote_prefix = @rtps.GuidPrefix::from_array([
    1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let remote = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(remote_prefix, data.participant_guid().entity_id()),
    data.vendor_id(),
    0U,
    60,
    0U,
    3U,
  )
  remote.add_metatraffic_unicast(
    @rtps.Locator::new(
      @rtps.LOCATOR_KIND_UDP_V6,
      7410U,
      Bytes::from_array(Array::make(16, 1)),
    ).unwrap(),
  )
  node.discovery.graph().ingest(Participant(remote))
  let second = @rtps.SedpEndpointData::new(
    Publication,
    @rtps.Guid::new(prefix, @rtps.EntityId::new(b"two", 0x02).unwrap()),
    "rt/second",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  // Unsupported peers do not prevent local registration or retained history.
  assert_true(node.register_endpoint(second) is Ok(_))
  assert_eq(node.local_endpoints().length(), 2)
  assert_eq(node.discovery.next_sedp_sequence_number(Publication), 3L)
  remote.add_metatraffic_unicast(
    @rtps.Locator::udp_v4(b"\x7F\x00\x00\x01", 7410U).unwrap(),
  )
  discovery_socket.close()
  // Once admitted, a send failure preserves both registration and queued effects.
  let third = @rtps.SedpEndpointData::new(
    Publication,
    @rtps.Guid::new(prefix, @rtps.EntityId::new(b"tri", 0x02).unwrap()),
    "rt/third",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  assert_true(node.register_endpoint(third) is Err(_))
  assert_eq(node.local_endpoints().length(), 3)
  assert_eq(node.discovery.next_sedp_sequence_number(Publication), 4L)
  assert_true(node.discovery.session.outgoing.length() > 0)
}
