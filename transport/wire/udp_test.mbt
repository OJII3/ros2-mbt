///|
async test "UDP binds an ephemeral loopback port" {
  let socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let address = socket.local_addr()
  assert_eq(address.ip(), 0x7F000001U)
  assert_true(address.port() > 0)
  socket.close()
}

///|
async test "UDP exposes its bound address as an RTPS locator" {
  let socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let locator = match socket.local_unicast_locator() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(locator.kind(), @rtps.LOCATOR_KIND_UDP_V4)
  assert_eq(locator.port(), socket.local_addr().port().reinterpret_as_uint())
  assert_eq(locator.address()[12], 0x7F)
  assert_eq(locator.address()[15], 0x01)
  socket.close()
}

///|
async test "UDP multicast sockets can use an explicit IPv4 interface" {
  let loopback = @socket.Addr::new(0x7F000001U, 0)
  let receiver = @wire.Udp::multicast(
    @socket.Addr::new(0xEFFF2A01U, 0),
    interface_addr=loopback,
  )
  let sender = @wire.Udp::bind(loopback)
  assert_eq(sender.set_multicast_interface(loopback), Ok(()))
  sender.close()
  receiver.close()
}

///|
async test "UDP DDSI constructors reject invalid domains before binding" {
  assert_true(@wire.Udp::ddsi_spdp_unicast(300, 0, 0x7F000001U) is Err(_))
  assert_true(@wire.Udp::ddsi_user_unicast(300, 0, 0x7F000001U) is Err(_))
}

///|
async test "UDP sends and receives one datagram" {
  let receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  sender.send_to(b"RTPS", receiver.local_addr())
  let (payload, source) = test_receive(() => receiver.receive())
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
  message.add(@rtps.Submessage::new(Data, 0x05, b"payload"))
  let receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  match sender.send_message(message, receiver.local_addr()) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (decoded, source) = match test_receive(() => receiver.receive_message()) {
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
  let receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
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
  let (decoded, source) = match test_receive(() => receiver.receive_data()) {
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
  let receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
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
  let (decoded, source) = match
    test_receive(() => receiver.receive_ros_discovery_info()) {
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
  let receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
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
  let (decoded, source) = match test_receive(() => receiver.receive_spdp()) {
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
      Publication,
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
  let receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
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
    test_receive(() => receiver.receive_sedp(Publication)) {
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
      Subscription,
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
  let receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let heartbeat = match
    @rtps.HeartbeatSubmessage::new(reader_id, writer_id, 1L, 1L, 1U) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match
    sender.send_heartbeat(
      heartbeat,
      prefix,
      @rtps.VendorId::new(1, 15),
      receiver.local_addr(),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
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
  let (event, source) = match test_receive(() => receiver.receive_discovery()) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match event {
    Subscription(decoded) => {
      assert_eq(decoded.kind(), Subscription)
      assert_eq(decoded.topic_name(), endpoint.topic_name())
    }
    Participant(_) => fail("expected an SEDP subscription event")
    Publication(_) => fail("expected an SEDP subscription event")
    EndpointRemoved(_, _) => fail("expected an SEDP subscription event")
    ParticipantRemoved(_) => fail("expected an SEDP subscription event")
  }
  assert_eq(source.ip(), 0x7F000001U)
  sender.close()
  receiver.close()
}

///|
async test "UDP sends SEDP to a participant metatraffic locator" {
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let endpoint_id = match @rtps.EntityId::new(b"abc", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let endpoint_guid = @rtps.Guid::new(prefix, endpoint_id)
  let endpoint = match
    @rtps.SedpEndpointData::new(
      Publication,
      endpoint_guid,
      "rt/chatter",
      "std_msgs::msg::dds_::String_",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let locator = match
    @rtps.Locator::udp_v4(
      b"\x7F\x00\x00\x01",
      receiver.local_addr().port().reinterpret_as_uint(),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let remote_participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(prefix, endpoint_id),
    @rtps.VendorId::new(1, 15),
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PUBLICATIONS_DETECTOR,
  )
  remote_participant.add_metatraffic_unicast(locator)
  match
    sender.send_sedp_to_participant(
      endpoint,
      @rtps.VendorId::new(1, 15),
      remote_participant,
      1L,
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (decoded, _) = match
    test_receive(() => receiver.receive_sedp(Publication)) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.topic_name(), "rt/chatter")
  assert_eq(decoded.type_name(), "std_msgs::msg::dds_::String_")
  let (heartbeat, _) = match test_receive(() => receiver.receive_heartbeat()) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(heartbeat.last_sequence_number(), 1L)
  match
    sender.send_sedp_dispose_to_participant(
      endpoint,
      @rtps.VendorId::new(1, 15),
      remote_participant,
      2L,
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (disposed, _) = match test_receive(() => receiver.receive_data()) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(disposed.writer_sequence_number(), 2L)
  assert_eq(disposed.serialized_payload(), endpoint.endpoint_guid().to_bytes())
  assert_eq(
    disposed.status_info(),
    Ok(Some(@rtps.STATUS_INFO_DISPOSED | @rtps.STATUS_INFO_UNREGISTERED)),
  )
  let (dispose_heartbeat, _) = match
    test_receive(() => receiver.receive_heartbeat()) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(dispose_heartbeat.last_sequence_number(), 2L)
  sender.close()
  receiver.close()
}
