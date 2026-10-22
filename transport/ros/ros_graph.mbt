///|
/// State for local ROS graph publication and remote graph readers.
///
/// Kept separate from `RosParticipant` so graph discovery can evolve without
/// expanding the participant's socket and DDSI lifecycle state.
pub struct RosGraph {
  mut graph_publication_id : @rtps.EntityId?
  mut graph_subscription_id : @rtps.EntityId?
  mut ros_node_namespace : String?
  mut ros_node_name : String?
  mut latest_graph_info : @ros_types.ParticipantEntitiesInfo?
  mut graph_publishers : Array[ReliableRosDiscoveryPublisher]
  mut graph_publisher_guids : Array[@rtps.Guid]
  mut graph_subscriptions : Array[ReliableRosDiscoverySubscription]
  mut graph_subscription_guids : Array[@rtps.Guid]
}

///|
/// Create an empty ROS graph-discovery state.
fn RosGraph::new() -> RosGraph {
  {
    graph_publication_id: None,
    graph_subscription_id: None,
    ros_node_namespace: None,
    ros_node_name: None,
    latest_graph_info: None,
    graph_publishers: [],
    graph_publisher_guids: [],
    graph_subscriptions: [],
    graph_subscription_guids: [],
  }
}
