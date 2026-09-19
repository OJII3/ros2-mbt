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
  match
    node.register_service_client(service, request_writer_id, response_reader_id) {
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
  let info = node.participant_entities_info("/demo", "client").unwrap()
  assert_eq(info.node_entities_info_seq()[0].writer_gid_seq().length(), 1)
  assert_eq(info.node_entities_info_seq()[0].reader_gid_seq().length(), 1)
  node.close()
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
  let info = match publisher.participant_entities_info("/demo", "talker") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match publisher.publish_ros_discovery_info(info) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
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
  publisher.close()
  subscriber.close()
}
