///|
async test "discovery service ingests ros_discovery_info samples" {
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let participant_id = match @rtps.EntityId::new(b"abc", 0xC1) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(prefix, participant_id),
    @rtps.VendorId::new(1, 15),
    0,
    60,
    0,
    0,
  )
  let spdp_reader = match @rtps.EntityId::new(b"rdr", 0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let spdp_writer = match @rtps.EntityId::new(b"wrt", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let receiver_address = receiver.local_addr()
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let session = match
    DiscoverySession::new(
      receiver, participant, spdp_reader, spdp_writer, receiver_address, 1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let service = DiscoveryService::new(session)
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
  match
    sender.send_ros_discovery_info(
      info,
      prefix,
      @rtps.VendorId::new(1, 15),
      spdp_reader,
      spdp_writer,
      1L,
      receiver_address,
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (source, decoded) = match service.receive_ros_discovery_info() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(source.ip(), 0x7F000001U)
  assert_eq(decoded.to_cdr_bytes(), info.to_cdr_bytes())
  assert_eq(service.graph().ros_participant_count(), 1)
  service.close()
  sender.close()
}

///|
async test "reliable ros_discovery_info reaches a discovered reader" {
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
  let publisher_id = match @rtps.EntityId::new(b"pub", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let subscriber_id = match @rtps.EntityId::new(b"sub", 0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let publisher_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let subscriber_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let publisher_locator = match
    @rtps.Locator::udp_v4(
      b"\x7F\x00\x00\x01",
      publisher_socket.local_addr().port().reinterpret_as_uint(),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let subscriber_locator = match
    @rtps.Locator::udp_v4(
      b"\x7F\x00\x00\x01",
      subscriber_socket.local_addr().port().reinterpret_as_uint(),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let publication = match
    @ros.ros_discovery_info_to_sedp(
      @rtps.SedpEndpointKind::Publication,
      @rtps.Guid::new(publisher_prefix, publisher_id),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let subscription = match
    @ros.ros_discovery_info_to_sedp(
      @rtps.SedpEndpointKind::Subscription,
      @rtps.Guid::new(subscriber_prefix, subscriber_id),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  publication.add_unicast_locator(publisher_locator)
  subscription.add_unicast_locator(subscriber_locator)
  let reader = match
    ReliableDataReaderSession::new_for_publication(
      subscriber_socket,
      subscriber_prefix,
      @rtps.VendorId::new(1, 15),
      subscriber_id,
      publication,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer = match
    ReliableDataWriter::new_for_subscription(
      publisher_socket,
      publisher_prefix,
      @rtps.VendorId::new(1, 15),
      publisher_id,
      subscription,
      1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let gid = match @ros.Gid::new(b"0123456789abcdef") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let info = @ros.ParticipantEntitiesInfo::new(gid)
  let node = match @ros.NodeEntitiesInfo::new("/demo", "talker") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_gid = @ros.Gid::from_guid(
    @rtps.Guid::new(publisher_prefix, publisher_id),
  )
  node.add_writer_gid(writer_gid)
  info.add_node(node)
  match writer.write(info.to_cdr_bytes()) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match writer.send_heartbeat() {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (data, source) = match reader.receive_data() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (heartbeat, _) = match reader.receive_heartbeat() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (acknack, _) = match writer.receive_acknack() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let decoded = match
    @ros.ParticipantEntitiesInfo::from_cdr_bytes(data.serialized_payload()) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.to_cdr_bytes(), info.to_cdr_bytes())
  assert_eq(decoded.node_entities_info_seq().length(), 1)
  assert_eq(heartbeat.last_sequence_number(), 1L)
  assert_eq(acknack.bitmap(), [0U])
  assert_eq(source.ip(), 0x7F000001U)
  writer.close()
  reader.close()
}
