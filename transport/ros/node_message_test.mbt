///|
async test "typed message endpoints advertise the descriptor identity" {
  let prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let participant = @wire.new_ddsi_participant(
    prefix,
    @rtps.VendorId::new(1, 15),
    0,
    0,
    0x7F000001U,
    60,
  ).unwrap()
  let discovery_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  defer discovery_socket.close()
  let user_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  defer user_socket.close()
  let participant = @ros.RosParticipant::from_sockets(
    discovery_socket, user_socket, participant, 0, 1L,
  ).unwrap()
  let node = @ros.RosNode::new(participant, "/typed_test", "typed_test").unwrap()
  defer node.close()

  let string_support = @ros_types.StringMessage::type_support()
  let pose_support = @ros_types.Pose::type_support()
  let string_publisher = node
    .create_publisher_for("/strings", string_support)
    .unwrap()
  let pose_publisher = node
    .create_publisher_for("/poses", pose_support)
    .unwrap()
  node
  .create_subscription_for("/strings", string_support, async fn(_) {  })
  .unwrap()
  node
  .create_subscription_for("/poses", pose_support, async fn(_) {  })
  .unwrap()

  let string_message = @ros_types.StringMessage::new("hello")
  let string_payload = string_support.encode(string_message).unwrap()
  assert_eq(
    string_support.decode(string_payload).unwrap().data(),
    string_message.data(),
  )
  let pose_message = @ros_types.Pose::default()
  let pose_payload = pose_support.encode(pose_message).unwrap()
  assert_eq(pose_support.decode(pose_payload).unwrap(), pose_message)

  let endpoints = participant.local_endpoints()
  assert_eq(endpoints.length(), 6)
  let mut string_count = 0
  let mut pose_count = 0
  for endpoint in endpoints {
    if endpoint.type_name() == "std_msgs::msg::dds_::String_" {
      assert_eq(endpoint.type_hash(), Ok(Some(string_support.type_hash())))
      assert_eq(endpoint.topic_name(), "rt/strings")
      string_count += 1
    }
    if endpoint.type_name() == "geometry_msgs::msg::dds_::Pose_" {
      assert_eq(endpoint.type_hash(), Ok(Some(pose_support.type_hash())))
      assert_eq(endpoint.topic_name(), "rt/poses")
      pose_count += 1
    }
  }
  assert_eq(string_count, 2)
  assert_eq(pose_count, 2)
  // The remaining two endpoints are the node's ROS graph endpoints.
  assert_eq(string_publisher.publish(string_message), Ok(()))
  assert_eq(pose_publisher.publish(pose_message), Ok(()))
}
