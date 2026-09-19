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
  let endpoint = match
    topic.to_sedp(
      @rtps.SedpEndpointKind::Publication,
      @rtps.Guid::new(prefix, writer_id),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match node.register_endpoint(endpoint) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  assert_eq(node.local_endpoints().length(), 1)
  assert_eq(
    node.local_endpoints()[0].participant_guid(),
    participant.participant_guid(),
  )
  assert_true(node.register_endpoint(endpoint) is Err(_))
  node.close()
}
