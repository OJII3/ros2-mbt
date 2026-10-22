///|
async test "RosNode::new_ddsi creates and closes a participant" {
  let failed = RosNode::new_ddsi(
    String::repeat("x", 257),
    "node_setup_test",
    domain_id=200U,
    participant_id=100U,
    ip=0x7F000001U,
  )
  assert_true(failed is Err(_))
  let node = match
    RosNode::new_ddsi(
      "/node_setup_test",
      "node_setup_test",
      domain_id=200U,
      participant_id=100U,
      ip=0x7F000001U,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let participant = node.participant.participant()
  assert_eq(participant.vendor_id(), @rtps.VendorId::new(1, 15))
  let prefix = participant.participant_guid().prefix().as_bytes().to_array()
  assert_eq(prefix[0], 1)
  assert_eq(prefix[1], 15)
  assert_eq(
    node.participant.ros_graph.ros_node_namespace,
    Some("/node_setup_test"),
  )
  assert_eq(node.participant.ros_graph.ros_node_name, Some("node_setup_test"))
  assert_true(node.participant.ros_graph.graph_publication_id is Some(_))
  assert_true(node.participant.ros_graph.graph_subscription_id is Some(_))
  node.dispose_and_close().unwrap()
}
