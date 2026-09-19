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
