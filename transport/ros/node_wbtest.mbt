///|
async test "executor skips malformed RTPS and decoder failures before valid data" {
  let prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let vendor_id = @rtps.VendorId::new(1, 15)
  let local_participant = @wire.new_ddsi_participant(
    prefix, vendor_id, 0, 0, 0x7F000001U, 60,
  ).unwrap()
  let discovery_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer discovery_socket.close()
  let user_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer user_socket.close()
  let participant = RosParticipant::from_sockets(
    discovery_socket, user_socket, local_participant, 0, 1L,
  ).unwrap()
  let node = RosNode::new(participant, "/node_test", "executor_test").unwrap()
  node.next_entity_key = 0x677068U
  let after_graph_key = node.next_entity_id(0x03).unwrap()
  assert_true(after_graph_key != @rtps.EntityId::new(b"gph", 0x03).unwrap())
  node.next_entity_key = 1U
  let topic = @ros_types.RosTopic::new("/chatter", "std_msgs", "msg", "String").unwrap()
  let executor = Executor::new()
  let mut received = 0
  node
  .create_subscription(
    topic,
    "test_type_hash",
    fn(payload) {
      if payload == b"valid" {
        Ok("valid")
      } else {
        Err("invalid test payload")
      }
    },
    async fn(value) {
      @async.Timer(1).wait()
      assert_eq(value, "valid")
      received += 1
      executor.shutdown()
    },
    qos=@rtps.SedpQos::best_effort(),
  )
  .unwrap()
  let node_publisher = node
    .create_publisher(
      topic,
      "test_type_hash",
      fn(_value : String) { Ok(b"local") },
      qos=@rtps.SedpQos::best_effort(),
    )
    .unwrap()
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer sender.close()
  let writer_id = @rtps.EntityId::new(b"pub", 0x03).unwrap()
  let remote_prefix = @rtps.GuidPrefix::from_array([
    11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
  ]).unwrap()
  let publication = topic
    .to_sedp_with_qos(
      Publication,
      @rtps.Guid::new(remote_prefix, writer_id),
      @rtps.SedpQos::new(
        @rtps.RELIABILITY_RELIABLE,
        @rtps.DURABILITY_TRANSIENT_LOCAL,
        @rtps.HISTORY_KEEP_LAST,
        1,
      ),
    )
    .unwrap()
  publication.add_unicast_locator(sender.local_unicast_locator().unwrap())
  node.add_publication(publication).unwrap()
  executor.add_node(node).unwrap()
  let incompatible_reader = topic
    .to_sedp_with_qos(
      Subscription,
      @rtps.Guid::new(
        @rtps.GuidPrefix::from_array([11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]).unwrap(),
        @rtps.EntityId::new(b"sub", 0x04).unwrap(),
      ),
      @rtps.SedpQos::new(
        @rtps.RELIABILITY_RELIABLE,
        @rtps.DURABILITY_VOLATILE,
        @rtps.HISTORY_KEEP_LAST,
        1,
      ),
    )
    .unwrap()
  incompatible_reader.add_unicast_locator(
    sender.local_unicast_locator().unwrap(),
  )
  node.handle_discovery_event(Subscription(incompatible_reader)).unwrap()
  assert_eq(node_publisher.publisher.writers.length(), 0)
  let unsupported_reader = topic
    .to_sedp_with_qos(
      Subscription,
      @rtps.Guid::new(
        @rtps.GuidPrefix::from_array([11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]).unwrap(),
        @rtps.EntityId::new(b"sub", 0x04).unwrap(),
      ),
      @rtps.SedpQos::new(
        @rtps.RELIABILITY_BEST_EFFORT,
        @rtps.DURABILITY_VOLATILE,
        @rtps.HISTORY_KEEP_LAST,
        1,
      ),
    )
    .unwrap()
  unsupported_reader.add_unicast_locator(
    @rtps.Locator::new(123, 0U, Bytes::make(16, 0)).unwrap(),
  )
  node.handle_discovery_event(Subscription(unsupported_reader)).unwrap()
  assert_eq(node_publisher.publisher.writers.length(), 0)
  sender.send_to(b"malformed RTPS", user_socket.local_addr())
  sender
  .send_message(
    @rtps.DataSubmessage::new(
      @rtps.EntityId::new([0, 0, 1], 0x04).unwrap(),
      writer_id,
      1L,
      b"bad CDR",
    ).to_message(remote_prefix, vendor_id),
    user_socket.local_addr(),
  )
  .unwrap()
  sender
  .send_message(
    @rtps.DataSubmessage::new(
      @rtps.EntityId::new([0, 0, 1], 0x04).unwrap(),
      writer_id,
      2L,
      b"valid",
    ).to_message(remote_prefix, vendor_id),
    user_socket.local_addr(),
  )
  .unwrap()
  @async.with_timeout(2000, () => executor.spin()).unwrap()
  assert_eq(received, 1)
}

///|
async test "shared user socket dispatches reliable ROS graph DATA and ACKNACK" {
  let local_prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let remote_prefix = @rtps.GuidPrefix::from_array([
    11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
  ]).unwrap()
  let vendor_id = @rtps.VendorId::new(1, 15)
  let local_identity = @wire.new_ddsi_participant(
    local_prefix, vendor_id, 0, 0, 0x7F000001U, 60,
  ).unwrap()
  let discovery_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer discovery_socket.close()
  let user_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer user_socket.close()
  let participant = RosParticipant::from_sockets(
    discovery_socket, user_socket, local_identity, 0, 1L,
  ).unwrap()
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer sender.close()
  let reader_id = @rtps.EntityId::new(b"sub", 0x04).unwrap()
  let writer_id = @rtps.EntityId::new(b"pub", 0x03).unwrap()
  participant.graph_subscription_id = Some(reader_id)
  participant.graph_publication_id = Some(writer_id)
  let incompatible_publication = @rtps.SedpEndpointData::new(
    Publication,
    @rtps.Guid::new(remote_prefix, writer_id),
    @ros_types.ROS_DISCOVERY_INFO_TOPIC_NAME,
    @ros_types.ROS_DISCOVERY_INFO_TYPE_NAME,
  ).unwrap()
  incompatible_publication.add_parameter(
    @rtps.qos_reliability(@rtps.RELIABILITY_RELIABLE, 0, 0),
  )
  incompatible_publication.add_parameter(
    @rtps.qos_durability(@rtps.DURABILITY_TRANSIENT_LOCAL),
  )
  incompatible_publication.add_unicast_locator(
    @rtps.Locator::new(123, 0U, Bytes::make(16, 0)).unwrap(),
  )
  participant
  .ensure_ros_discovery_publication(incompatible_publication)
  .unwrap()
  let incompatible_subscription = @rtps.SedpEndpointData::new(
    Subscription,
    @rtps.Guid::new(remote_prefix, reader_id),
    @ros_types.ROS_DISCOVERY_INFO_TOPIC_NAME,
    @ros_types.ROS_DISCOVERY_INFO_TYPE_NAME,
  ).unwrap()
  incompatible_subscription.add_parameter(
    @rtps.qos_reliability(@rtps.RELIABILITY_RELIABLE, 0, 0),
  )
  incompatible_subscription.add_unicast_locator(
    @rtps.Locator::new(123, 0U, Bytes::make(16, 0)).unwrap(),
  )
  participant
  .ensure_ros_discovery_subscription(incompatible_subscription, false)
  .unwrap()
  assert_eq(participant.graph_subscriptions.length(), 0)
  assert_eq(participant.graph_publishers.length(), 0)
  let publication = @ros_types.ros_discovery_info_to_sedp(
    Publication,
    @rtps.Guid::new(remote_prefix, writer_id),
  ).unwrap()
  publication.add_unicast_locator(sender.local_unicast_locator().unwrap())
  let subscription = @ros_types.ros_discovery_info_to_sedp(
    Subscription,
    @rtps.Guid::new(local_prefix, reader_id),
  ).unwrap()
  subscription.add_unicast_locator(user_socket.local_unicast_locator().unwrap())
  let graph_reader = ReliableRosDiscoverySubscription::new_for_publication(
    user_socket, local_prefix, vendor_id, reader_id, publication,
  ).unwrap()
  let graph_writer = ReliableRosDiscoveryPublisher::new_for_subscription(
    sender, remote_prefix, vendor_id, writer_id, subscription, 1L,
  ).unwrap()
  participant.graph_subscriptions.push(graph_reader)
  participant.graph_publishers.push(graph_writer)
  let gid = @ros_types.Gid::from_guid(@rtps.Guid::new(remote_prefix, writer_id))
  let info = @ros_types.ParticipantEntitiesInfo::new(gid)
  let graph_node = @ros_types.NodeEntitiesInfo::new("/demo", "talker").unwrap()
  graph_node.add_writer_gid(gid)
  info.add_node(graph_node)
  participant.graph_publishers[0].announce_once(info).unwrap()
  let (data_message, data_source) = @async.with_timeout(2000, () => {
    user_socket.receive_message()
  }).unwrap()
  participant.handle_user_message(data_message, data_source).unwrap()
  let (heartbeat_message, heartbeat_source) = @async.with_timeout(2000, () => {
    user_socket.receive_message()
  }).unwrap()
  participant.handle_user_message(heartbeat_message, heartbeat_source).unwrap()
  let (acknack_message, acknack_source) = @async.with_timeout(2000, () => {
    sender.receive_message()
  }).unwrap()
  participant.handle_user_message(acknack_message, acknack_source).unwrap()
  assert_eq(participant.graph().ros_participant_count(), 1)
  assert_eq(participant.graph_subscriptions[0].sample_count(), 1)
  assert_eq(participant.graph_publishers[0].history_length(), 0)
}

///|
async test "periodic graph HEARTBEAT recovers a missed initial DATA sample" {
  let local_prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let remote_prefix = @rtps.GuidPrefix::from_array([
    11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
  ]).unwrap()
  let vendor_id = @rtps.VendorId::new(1, 15)
  let local_identity = @wire.new_ddsi_participant(
    local_prefix, vendor_id, 0, 0, 0x7F000001U, 60,
  ).unwrap()
  let discovery_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer discovery_socket.close()
  let user_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer user_socket.close()
  let participant = RosParticipant::from_sockets(
    discovery_socket, user_socket, local_identity, 0, 1L,
  ).unwrap()
  let node = RosNode::new(participant, "/node_test", "heartbeat_test").unwrap()
  let remote_receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer remote_receiver.close()
  let publication_id = @rtps.EntityId::new(b"gph", 0x03).unwrap()
  let subscription_id = @rtps.EntityId::new(b"gph", 0x04).unwrap()
  let local_publication = @ros_types.ros_discovery_info_to_sedp(
    Publication,
    @rtps.Guid::new(local_prefix, publication_id),
  ).unwrap()
  local_publication.add_unicast_locator(
    user_socket.local_unicast_locator().unwrap(),
  )
  let remote_subscription = @ros_types.ros_discovery_info_to_sedp(
    Subscription,
    @rtps.Guid::new(remote_prefix, subscription_id),
  ).unwrap()
  remote_subscription.add_unicast_locator(
    remote_receiver.local_unicast_locator().unwrap(),
  )
  let remote_reader = ReliableRosDiscoverySubscription::new_for_publication(
    remote_receiver, remote_prefix, vendor_id, subscription_id, local_publication,
  ).unwrap()
  let local_writer = ReliableRosDiscoveryPublisher::new_for_subscription(
    user_socket, local_prefix, vendor_id, publication_id, remote_subscription, 1L,
  ).unwrap()
  node.participant.graph_publishers.push(local_writer)
  let gid = @ros_types.Gid::from_guid(
    @rtps.Guid::new(local_prefix, publication_id),
  )
  let info = @ros_types.ParticipantEntitiesInfo::new(gid)
  let graph_node = @ros_types.NodeEntitiesInfo::new("/demo", "talker").unwrap()
  graph_node.add_writer_gid(gid)
  info.add_node(graph_node)
  node.participant.graph_publishers[0].announce_once(info).unwrap()
  ignore(remote_receiver.receive_message().unwrap())
  ignore(remote_receiver.receive_message().unwrap())
  let executor = Executor::new()
  executor.add_node(node).unwrap()
  @async.with_task_group() <| group => {
    group.spawn_bg(no_wait=true) <| () => {
      match executor.spin() {
        Ok(_) => ()
        Err(message) => fail(message)
      }
    }
    let (heartbeat, _) = @async.with_timeout(3000, () => {
      remote_reader.receive_heartbeat()
    }).unwrap()
    assert_true(heartbeat.last_sequence_number() >= 1L)
    let (recovered_info, _) = @async.with_timeout(3000, () => {
      remote_reader.receive()
    }).unwrap()
    assert_eq(recovered_info.to_cdr_bytes(), info.to_cdr_bytes())
    executor.shutdown()
  }
}

///|
async test "RosNode enforces QoS compatibility for publishers and subscriptions" {
  let prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let vendor_id = @rtps.VendorId::new(1, 15)
  let local_participant = @wire.new_ddsi_participant(
    prefix, vendor_id, 0, 0, 0x7F000001U, 60,
  ).unwrap()
  let discovery_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer discovery_socket.close()
  let user_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer user_socket.close()
  let participant = RosParticipant::from_sockets(
    discovery_socket, user_socket, local_participant, 0, 1L,
  ).unwrap()
  let node = RosNode::new(participant, "/demo", "qos_test").unwrap()
  let topic = @ros_types.RosTopic::new(
    "/test_topic", "std_msgs", "msg", "String",
  ).unwrap()

  // 1. Create a best-effort publisher
  let be_publisher = node
    .create_publisher(
      topic,
      "test_hash",
      fn(_v : String) { Ok(b"data") },
      qos=@rtps.SedpQos::best_effort(),
    )
    .unwrap()

  // 2. Create a reliable publisher (default QoS)
  let rel_publisher = node
    .create_publisher(topic, "test_hash", fn(_v : String) { Ok(b"data") })
    .unwrap()

  let dummy_locator = @rtps.Locator::udp_v4(b"\x7F\x00\x00\x01", 12345U).unwrap()
  let remote_prefix = @rtps.GuidPrefix::from_array([
    11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
  ]).unwrap()

  let remote_rel_sub = topic
    .to_sedp_with_qos(
      Subscription,
      @rtps.Guid::new(remote_prefix, @rtps.EntityId::new(b"sb1", 0x04).unwrap()),
      @rtps.SedpQos::reliable(),
    )
    .unwrap()
  remote_rel_sub.add_unicast_locator(dummy_locator)

  let remote_be_sub = topic
    .to_sedp_with_qos(
      Subscription,
      @rtps.Guid::new(remote_prefix, @rtps.EntityId::new(b"sb2", 0x04).unwrap()),
      @rtps.SedpQos::best_effort(),
    )
    .unwrap()
  remote_be_sub.add_unicast_locator(dummy_locator)

  // Best-effort publisher does NOT match a reliable subscription
  node.handle_discovery_event(Subscription(remote_rel_sub)).unwrap()
  assert_eq(be_publisher.publisher.writers.length(), 0)

  // Reliable publisher DOES match reliable subscription
  assert_eq(rel_publisher.publisher.writers.length(), 1)

  // Discovered best-effort subscription matches both best-effort and reliable publishers
  node.handle_discovery_event(Subscription(remote_be_sub)).unwrap()
  assert_eq(be_publisher.publisher.writers.length(), 1)
  assert_eq(rel_publisher.publisher.writers.length(), 2)

  // 3. Create a reliable subscription (default) and best-effort subscription on the node
  let mut sub_received = 0
  node
  .create_subscription(topic, "test_hash", fn(b) { Ok(b) }, async fn(_b) {
    @async.Timer(1).wait()
    sub_received += 1
  })
  .unwrap()
  node
  .create_subscription(
    topic,
    "test_hash",
    fn(b) { Ok(b) },
    async fn(_b) {
      @async.Timer(1).wait()
      sub_received += 1
    },
    qos=@rtps.SedpQos::best_effort(),
  )
  .unwrap()

  let remote_be_pub = topic
    .to_sedp_with_qos(
      Publication,
      @rtps.Guid::new(remote_prefix, @rtps.EntityId::new(b"pb1", 0x03).unwrap()),
      @rtps.SedpQos::best_effort(),
    )
    .unwrap()
  remote_be_pub.add_unicast_locator(dummy_locator)

  let remote_rel_pub = topic
    .to_sedp_with_qos(
      Publication,
      @rtps.Guid::new(remote_prefix, @rtps.EntityId::new(b"pb2", 0x03).unwrap()),
      @rtps.SedpQos::reliable(),
    )
    .unwrap()
  remote_rel_pub.add_unicast_locator(dummy_locator)

  // Reliable subscription (index 0) does NOT match best-effort publication
  // Best-effort subscription (index 1) DOES match best-effort publication
  node.handle_discovery_event(Publication(remote_be_pub)).unwrap()
  assert_eq(node.subscriptions[0].readers.length(), 0)
  assert_eq(node.subscriptions[1].readers.length(), 1)

  // Reliable subscription DOES match reliable publication
  // Best-effort subscription DOES match reliable publication
  node.handle_discovery_event(Publication(remote_rel_pub)).unwrap()
  assert_eq(node.subscriptions[0].readers.length(), 1)
  assert_eq(node.subscriptions[1].readers.length(), 2)
  assert_eq(sub_received, 0)
}

///|
fn wbtest_message_has_submessage(
  message : @rtps.Message,
  id : @rtps.SubmessageId,
) -> Bool {
  for submessage in message.submessages() {
    if submessage.id() == id {
      return true
    }
  }
  false
}

///|
async test "reliable RosNode publisher recovers dropped DATA sample via HEARTBEAT and ACKNACK" {
  let local_prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let remote_prefix = @rtps.GuidPrefix::from_array([
    11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
  ]).unwrap()
  let vendor_id = @rtps.VendorId::new(1, 15)
  let local_identity = @wire.new_ddsi_participant(
    local_prefix, vendor_id, 0, 0, 0x7F000001U, 60,
  ).unwrap()
  let discovery_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer discovery_socket.close()
  let user_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer user_socket.close()
  let participant = RosParticipant::from_sockets(
    discovery_socket, user_socket, local_identity, 0, 1L,
  ).unwrap()
  let node = RosNode::new(participant, "/node_test", "reliable_pub_test").unwrap()
  let topic = @ros_types.RosTopic::new(
    "/reliable_chatter", "std_msgs", "msg", "String",
  ).unwrap()

  let publisher = node
    .create_publisher(
      topic,
      "test_type_hash",
      fn(value : Bytes) { Ok(value) },
      qos=@rtps.SedpQos::reliable(),
    )
    .unwrap()

  let remote_receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer remote_receiver.close()

  let writer_id = @rtps.EntityId::new(b"\x00\x00\x01", 0x03).unwrap()
  let reader_id = @rtps.EntityId::new(b"sub", 0x04).unwrap()

  let local_pub_sedp = topic
    .to_sedp_with_qos(
      Publication,
      @rtps.Guid::new(local_prefix, writer_id),
      @rtps.SedpQos::reliable(),
    )
    .unwrap()
  local_pub_sedp.add_unicast_locator(
    user_socket.local_unicast_locator().unwrap(),
  )

  let remote_sub_sedp = topic
    .to_sedp_with_qos(
      Subscription,
      @rtps.Guid::new(remote_prefix, reader_id),
      @rtps.SedpQos::reliable(),
    )
    .unwrap()
  remote_sub_sedp.add_unicast_locator(
    remote_receiver.local_unicast_locator().unwrap(),
  )

  node.handle_discovery_event(Subscription(remote_sub_sedp)).unwrap()
  assert_eq(publisher.publisher.writers.length(), 1)

  let remote_subscription = ReliableRosSubscription::new_for_publication(
    topic, remote_receiver, remote_prefix, vendor_id, reader_id, local_pub_sedp,
  ).unwrap()

  publisher.publish(b"reliable_message").unwrap()

  let (datagram1, source1) = @async.with_timeout(2000, () => {
    remote_receiver.receive_message()
  }).unwrap()
  let (datagram2, source2) = @async.with_timeout(2000, () => {
    remote_receiver.receive_message()
  }).unwrap()

  let (_dropped_data, hb_msg, hb_source) = if wbtest_message_has_submessage(
      datagram1,
      @rtps.SubmessageId::Data,
    ) {
    (datagram1, datagram2, source2)
  } else {
    (datagram2, datagram1, source1)
  }

  // Dropping initial DATA; deliver only HEARTBEAT to remote subscription
  let samples_from_hb = remote_subscription
    .handle_message(hb_msg, hb_source)
    .unwrap()
  assert_eq(samples_from_hb.length(), 0)

  let executor = Executor::new()
  executor.add_node(node).unwrap()

  @async.with_task_group() <| group => {
    group.spawn_bg(no_wait=true) <| () => {
      match executor.spin() {
        Ok(_) => ()
        Err(message) => fail(message)
      }
    }

    let (retransmitted_msg, retransmitted_source) = @async.with_timeout(3000, () => {
      remote_receiver.receive_message()
    }).unwrap()

    let recovered_samples = remote_subscription
      .handle_message(retransmitted_msg, retransmitted_source)
      .unwrap()
    assert_eq(recovered_samples.length(), 1)
    assert_eq(recovered_samples[0], b"reliable_message")
    executor.shutdown()
  }
}

///|
async test "two RosNodes exchange typed reliable messages through Executor" {
  let prefix1 = @rtps.GuidPrefix::from_array([
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12,
  ]).unwrap()
  let prefix2 = @rtps.GuidPrefix::from_array([
    12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1,
  ]).unwrap()
  let vendor_id = @rtps.VendorId::new(1, 15)

  let participant_id1 = @wire.new_ddsi_participant(
    prefix1, vendor_id, 0, 0, 0x7F000001U, 60,
  ).unwrap()
  let disc_sock1 = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer disc_sock1.close()
  let user_sock1 = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer user_sock1.close()
  let participant1 = RosParticipant::from_sockets(
    disc_sock1, user_sock1, participant_id1, 0, 1L,
  ).unwrap()
  let node1 = RosNode::new(participant1, "/demo", "talker").unwrap()
  defer node1.close()

  let participant_id2 = @wire.new_ddsi_participant(
    prefix2, vendor_id, 0, 0, 0x7F000001U, 60,
  ).unwrap()
  let disc_sock2 = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer disc_sock2.close()
  let user_sock2 = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer user_sock2.close()
  let participant2 = RosParticipant::from_sockets(
    disc_sock2, user_sock2, participant_id2, 0, 1L,
  ).unwrap()
  let node2 = RosNode::new(participant2, "/demo", "listener").unwrap()
  defer node2.close()

  let executor = Executor::new()
  let string_support = @ros_types.StringMessage::type_support()

  let publisher = node1
    .create_publisher_for("/chatter", string_support)
    .unwrap()

  let mut received_msg = ""
  node2
  .create_subscription_for("/chatter", string_support, async fn(msg) {
    @async.Timer(1).wait()
    received_msg = msg.data()
    executor.shutdown()
  })
  .unwrap()

  // Exchange local SEDP endpoints between the two nodes
  for endpoint in participant1.local_endpoints() {
    if endpoint.topic_name() == "rt/chatter" {
      node2.handle_discovery_event(Publication(endpoint)).unwrap()
    }
  }
  for endpoint in participant2.local_endpoints() {
    if endpoint.topic_name() == "rt/chatter" {
      node1.handle_discovery_event(Subscription(endpoint)).unwrap()
    }
  }

  executor.add_node(node1).unwrap()
  executor.add_node(node2).unwrap()

  // Publish typed message
  publisher.publish(@ros_types.StringMessage::new("hello from talker")).unwrap()

  @async.with_timeout(3000, () => executor.spin()).unwrap()
  assert_eq(received_msg, "hello from talker")
}
