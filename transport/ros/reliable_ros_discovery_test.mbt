///|
async test "reliable ROS graph facade exchanges participant entities" {
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match @rtps.EntityId::new(b"pub", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let reader_id = match @rtps.EntityId::new(b"sub", 0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let receiver_locator = match receiver.local_unicast_locator() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let sender_locator = match sender.local_unicast_locator() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let publication = match
    @ros_types.ros_discovery_info_to_sedp(
      Publication,
      @rtps.Guid::new(prefix, writer_id),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  publication.add_unicast_locator(sender_locator)
  let subscription = match
    @ros_types.ros_discovery_info_to_sedp(
      Subscription,
      @rtps.Guid::new(prefix, reader_id),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  subscription.add_unicast_locator(receiver_locator)
  let publisher = match
    ReliableRosDiscoveryPublisher::new_for_subscription(
      sender,
      prefix,
      @rtps.VendorId::new(1, 15),
      writer_id,
      subscription,
      1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let subscriber = match
    ReliableRosDiscoverySubscription::new_for_publication(
      receiver,
      prefix,
      @rtps.VendorId::new(1, 15),
      reader_id,
      publication,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let gid = match @ros_types.Gid::new(b"0123456789abcdef") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let info = @ros_types.ParticipantEntitiesInfo::new(gid)
  let node = match @ros_types.NodeEntitiesInfo::new("/demo", "talker") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  node.add_writer_gid(
    @ros_types.Gid::from_guid(@rtps.Guid::new(prefix, writer_id)),
  )
  info.add_node(node)
  match publisher.announce_once(info) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (decoded, source) = match subscriber.receive() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (heartbeat, _) = match subscriber.receive_heartbeat() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (acknack, _) = match publisher.receive_acknack() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.to_cdr_bytes(), info.to_cdr_bytes())
  assert_eq(decoded.node_entities_info_seq().length(), 1)
  assert_eq(heartbeat.last_sequence_number(), 1L)
  assert_eq(acknack.bitmap_base(), 2L)
  assert_eq(acknack.num_bits(), 0U)
  assert_eq(acknack.bitmap(), [])
  assert_eq(publisher.history_length(), 0)
  assert_eq(subscriber.sample_count(), 1)
  assert_eq(source.ip(), 0x7F000001U)
  publisher.close()
  subscriber.close()
}

///|
test "ROS graph endpoint validation requires reliable matching SEDP data" {
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match @rtps.EntityId::new(b"pub", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let endpoint = match
    @rtps.SedpEndpointData::new(
      Publication,
      @rtps.Guid::new(prefix, writer_id),
      @ros_types.ROS_DISCOVERY_INFO_TOPIC_NAME,
      @ros_types.ROS_DISCOVERY_INFO_TYPE_NAME,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  endpoint.add_parameter(
    @rtps.qos_reliability(@rtps.RELIABILITY_BEST_EFFORT, 0, 0),
  )
  assert_true(
    @ros_types.validate_ros_discovery_info_endpoint(endpoint, Publication)
    is Err(_),
  )
}
