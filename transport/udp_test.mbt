///|
async test "UDP binds an ephemeral loopback port" {
  let socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let address = socket.local_addr()
  assert_eq(address.ip(), 0x7F000001U)
  assert_true(address.port() > 0)
  socket.close()
}

///|
async test "UDP sends and receives one datagram" {
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  sender.send_to(b"RTPS", receiver.local_addr())
  let (payload, source) = receiver.receive()
  assert_eq(payload, b"RTPS")
  assert_eq(source.ip(), 0x7F000001U)
  sender.close()
  receiver.close()
}

///|
async test "UDP sends and receives one RTPS message" {
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let header = @rtps.Header::new(prefix, @rtps.VendorId::new(1, 15))
  let message = @rtps.Message::new(header)
  message.add(@rtps.Submessage::new(@rtps.SubmessageId::Data, 0x05, b"payload"))
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  match sender.send_message(message, receiver.local_addr()) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (decoded, source) = match receiver.receive_message() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded, message)
  assert_eq(source.ip(), 0x7F000001U)
  sender.close()
  receiver.close()
}

///|
async test "UDP sends and receives one DATA sample" {
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let reader_id = match @rtps.EntityId::new(b"rdr", 0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match @rtps.EntityId::new(b"wrt", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let data = @rtps.DataSubmessage::new(reader_id, writer_id, 4L, b"payload")
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  match
    sender.send_data(
      data,
      prefix,
      @rtps.VendorId::new(1, 15),
      receiver.local_addr(),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (decoded, source) = match receiver.receive_data() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded, data)
  assert_eq(source.ip(), 0x7F000001U)
  sender.close()
  receiver.close()
}

///|
async test "UDP sends and receives ROS graph-discovery info" {
  let gid = match @ros.Gid::new(b"0123456789abcdef") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let info = @ros.ParticipantEntitiesInfo::new(gid)
  let node = match @ros.NodeEntitiesInfo::new("/demo", "talker") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  info.add_node(node)
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let reader_id = match @rtps.EntityId::new(b"rdr", 0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match @rtps.EntityId::new(b"wrt", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  match
    sender.send_ros_discovery_info(
      info,
      prefix,
      @rtps.VendorId::new(1, 15),
      reader_id,
      writer_id,
      1L,
      receiver.local_addr(),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (decoded, source) = match receiver.receive_ros_discovery_info() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.to_cdr_bytes(), info.to_cdr_bytes())
  assert_eq(source.ip(), 0x7F000001U)
  sender.close()
  receiver.close()
}

///|
async test "UDP sends and receives one SPDP announcement" {
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let participant_id = match @rtps.EntityId::new(b"abc", 0xC1) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let participant_guid = @rtps.Guid::new(prefix, participant_id)
  let participant = @rtps.SpdpParticipantData::new(
    participant_guid,
    @rtps.VendorId::new(1, 15),
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR,
  )
  let reader_id = match @rtps.EntityId::new(b"rdr", 0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match @rtps.EntityId::new(b"wrt", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  match
    sender.send_spdp(
      participant,
      reader_id,
      writer_id,
      1L,
      receiver.local_addr(),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (decoded, source) = match receiver.receive_spdp() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.to_cdr_bytes(), participant.to_cdr_bytes())
  assert_eq(source.ip(), 0x7F000001U)
  sender.close()
  receiver.close()
}

///|
async test "UDP sends and receives one SEDP announcement" {
  let endpoint_guid = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(prefix) =>
      match @rtps.EntityId::new(b"abc", 0xC2) {
        Ok(entity_id) => @rtps.Guid::new(prefix, entity_id)
        Err(message) => fail(message)
      }
    Err(message) => fail(message)
  }
  let endpoint = match
    @rtps.SedpEndpointData::new(
      @rtps.SedpEndpointKind::Publication,
      endpoint_guid,
      "rt/chatter",
      "std_msgs::msg::dds_::String_",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  endpoint.add_parameter(
    @rtps.qos_reliability(@rtps.RELIABILITY_RELIABLE, 0, 0),
  )
  let reader_id = match @rtps.EntityId::new(b"rdr", 0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match @rtps.EntityId::new(b"wrt", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  match
    sender.send_sedp(
      endpoint,
      @rtps.VendorId::new(1, 15),
      reader_id,
      writer_id,
      1L,
      receiver.local_addr(),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (decoded, source) = match
    receiver.receive_sedp(@rtps.SedpEndpointKind::Publication) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.topic_name(), endpoint.topic_name())
  assert_eq(decoded.type_name(), endpoint.type_name())
  assert_eq(source.ip(), 0x7F000001U)
  sender.close()
  receiver.close()
}

///|
async test "UDP classifies discovery samples by builtin writer" {
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let endpoint_guid = match @rtps.EntityId::new(b"abc", 0xC2) {
    Ok(entity_id) => @rtps.Guid::new(prefix, entity_id)
    Err(message) => fail(message)
  }
  let endpoint = match
    @rtps.SedpEndpointData::new(
      @rtps.SedpEndpointKind::Subscription,
      endpoint_guid,
      "rt/chatter",
      "std_msgs::msg::dds_::String_",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let reader_id = match @rtps.EntityId::new(b"\x00\x00\x04", 0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match @rtps.EntityId::new(b"\x00\x00\x04", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  match
    sender.send_sedp(
      endpoint,
      @rtps.VendorId::new(1, 15),
      reader_id,
      writer_id,
      1L,
      receiver.local_addr(),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (event, source) = match receiver.receive_discovery() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match event {
    DiscoveryEvent::Subscription(decoded) => {
      assert_eq(decoded.kind(), @rtps.SedpEndpointKind::Subscription)
      assert_eq(decoded.topic_name(), endpoint.topic_name())
    }
    DiscoveryEvent::Participant(_) =>
      fail("expected an SEDP subscription event")
    DiscoveryEvent::Publication(_) =>
      fail("expected an SEDP subscription event")
  }
  assert_eq(source.ip(), 0x7F000001U)
  sender.close()
  receiver.close()
}
