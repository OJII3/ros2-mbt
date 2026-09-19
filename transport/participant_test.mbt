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
  assert_true(node.register_endpoint(node.local_endpoints()[0]) is Err(_))
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
  match subscriber.receive_discovery_once() {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  assert_eq(subscriber.graph().participant_count(), 1)
  assert_eq(subscriber.graph().publication_count(), 1)
  publisher.close()
  subscriber.close()
}
