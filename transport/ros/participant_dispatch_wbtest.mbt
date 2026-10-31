///|
async test "participant dispatcher recovers a dropped graph announcement" {
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
  participant.ros_graph.graph_publishers.push(local_writer)
  let gid = @ros_types.Gid::from_guid(
    @rtps.Guid::new(local_prefix, publication_id),
  )
  let info = @ros_types.ParticipantEntitiesInfo::new(gid)
  let graph_node = @ros_types.NodeEntitiesInfo::new("/demo", "talker").unwrap()
  graph_node.add_writer_gid(gid)
  info.add_node(graph_node)
  participant.ros_graph.graph_publishers[0].announce_once(info).unwrap()
  ignore(remote_receiver.receive_message().unwrap())
  ignore(remote_receiver.receive_message().unwrap())
  participant.send_ros_discovery_heartbeats().unwrap()
  ignore(
    @async.with_timeout(3000, () => remote_reader.receive_heartbeat()).unwrap(),
  )
  let (message, source) = @async.with_timeout(3000, () => {
    user_socket.receive_message()
  }).unwrap()
  participant.handle_user_message(message, source).unwrap()
  let (recovered, _) = @async.with_timeout(3000, () => remote_reader.receive()).unwrap()
  assert_eq(recovered.to_cdr_bytes(), info.to_cdr_bytes())
}
