///|
async test "executor skips malformed RTPS and decoder failures before valid data" {
  let prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let vendor_id = @rtps.VendorId::new(1, 15)
  let local_participant = @wire.new_ddsi_participant(
    prefix, vendor_id, 0, 0, 0x7F000001U, 60,
  ).unwrap()
  let discovery_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  defer discovery_socket.close()
  let user_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
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
      assert_eq(value, "valid")
      received += 1
      executor.shutdown()
    },
  )
  .unwrap()
  let node_publisher = node
    .create_publisher(topic, "test_type_hash", fn(_value : String) {
      Ok(b"local")
    })
    .unwrap()
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
  node.add_publication(publication).unwrap()
  executor.add_node(node).unwrap()
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  defer sender.close()
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
  let discovery_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  defer discovery_socket.close()
  let user_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  defer user_socket.close()
  let participant = RosParticipant::from_sockets(
    discovery_socket, user_socket, local_identity, 0, 1L,
  ).unwrap()
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
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
