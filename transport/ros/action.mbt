///|
/// The matching remote endpoints for one ROS 2 action client.
pub struct RosActionEndpoints {
  send_goal_request_subscription : @rtps.SedpEndpointData
  send_goal_response_publication : @rtps.SedpEndpointData
  get_result_request_subscription : @rtps.SedpEndpointData
  get_result_response_publication : @rtps.SedpEndpointData
  cancel_goal_request_subscription : @rtps.SedpEndpointData
  cancel_goal_response_publication : @rtps.SedpEndpointData
  feedback_publication : @rtps.SedpEndpointData
  status_publication : @rtps.SedpEndpointData
}

///|
/// Discover the service and topic endpoints for a ROS 2 action.
pub async fn RosActionEndpoints::discover(
  participant : RosParticipant,
  action : @ros_types.RosAction,
) -> Result[RosActionEndpoints, String] {
  let send_goal = action.send_goal_service()
  let get_result = action.get_result_service()
  let cancel_goal = action.cancel_goal_service()
  let feedback_topic = action.feedback_topic()
  let status_topic = action.status_topic()
  let mut send_goal_request_subscription : @rtps.SedpEndpointData? = None
  let mut send_goal_response_publication : @rtps.SedpEndpointData? = None
  let mut get_result_request_subscription : @rtps.SedpEndpointData? = None
  let mut get_result_response_publication : @rtps.SedpEndpointData? = None
  let mut cancel_goal_request_subscription : @rtps.SedpEndpointData? = None
  let mut cancel_goal_response_publication : @rtps.SedpEndpointData? = None
  let mut feedback_publication : @rtps.SedpEndpointData? = None
  let mut status_publication : @rtps.SedpEndpointData? = None
  while send_goal_request_subscription is None ||
        send_goal_response_publication is None ||
        get_result_request_subscription is None ||
        get_result_response_publication is None ||
        cancel_goal_request_subscription is None ||
        cancel_goal_response_publication is None ||
        feedback_publication is None ||
        status_publication is None {
    match participant.receive_discovery_once() {
      Ok((_, @wire.DiscoveryEvent::Publication(publication))) => {
        if publication.topic_name() == send_goal.dds_response_name() &&
          publication.type_name() == send_goal.dds_response_type_name() {
          send_goal_response_publication = Some(publication)
        }
        if publication.topic_name() == get_result.dds_response_name() &&
          publication.type_name() == get_result.dds_response_type_name() {
          get_result_response_publication = Some(publication)
        }
        if publication.topic_name() == cancel_goal.dds_response_name() &&
          publication.type_name() == cancel_goal.dds_response_type_name() {
          cancel_goal_response_publication = Some(publication)
        }
        if publication.topic_name() == feedback_topic.dds_name() &&
          publication.type_name() == feedback_topic.dds_type_name() {
          feedback_publication = Some(publication)
        }
        if publication.topic_name() == status_topic.dds_name() &&
          publication.type_name() == status_topic.dds_type_name() {
          status_publication = Some(publication)
        }
      }
      Ok((_, @wire.DiscoveryEvent::Subscription(subscription))) => {
        if subscription.topic_name() == send_goal.dds_request_name() &&
          subscription.type_name() == send_goal.dds_request_type_name() {
          send_goal_request_subscription = Some(subscription)
        }
        if subscription.topic_name() == get_result.dds_request_name() &&
          subscription.type_name() == get_result.dds_request_type_name() {
          get_result_request_subscription = Some(subscription)
        }
        if subscription.topic_name() == cancel_goal.dds_request_name() &&
          subscription.type_name() == cancel_goal.dds_request_type_name() {
          cancel_goal_request_subscription = Some(subscription)
        }
      }
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  match
    (
      send_goal_request_subscription, send_goal_response_publication, get_result_request_subscription,
      get_result_response_publication, cancel_goal_request_subscription, cancel_goal_response_publication,
      feedback_publication, status_publication,
    ) {
    (
      Some(send_goal_request_subscription),
      Some(send_goal_response_publication),
      Some(get_result_request_subscription),
      Some(get_result_response_publication),
      Some(cancel_goal_request_subscription),
      Some(cancel_goal_response_publication),
      Some(feedback_publication),
      Some(status_publication),
    ) =>
      Ok({
        send_goal_request_subscription,
        send_goal_response_publication,
        get_result_request_subscription,
        get_result_response_publication,
        cancel_goal_request_subscription,
        cancel_goal_response_publication,
        feedback_publication,
        status_publication,
      })
    _ => Err("discovery ended without matching ROS action services")
  }
}

///|
pub fn RosActionEndpoints::send_goal_request_subscription(
  self : RosActionEndpoints,
) -> @rtps.SedpEndpointData {
  self.send_goal_request_subscription
}

///|
pub fn RosActionEndpoints::send_goal_response_publication(
  self : RosActionEndpoints,
) -> @rtps.SedpEndpointData {
  self.send_goal_response_publication
}

///|
pub fn RosActionEndpoints::get_result_request_subscription(
  self : RosActionEndpoints,
) -> @rtps.SedpEndpointData {
  self.get_result_request_subscription
}

///|
pub fn RosActionEndpoints::get_result_response_publication(
  self : RosActionEndpoints,
) -> @rtps.SedpEndpointData {
  self.get_result_response_publication
}

///|
pub fn RosActionEndpoints::cancel_goal_request_subscription(
  self : RosActionEndpoints,
) -> @rtps.SedpEndpointData {
  self.cancel_goal_request_subscription
}

///|
pub fn RosActionEndpoints::cancel_goal_response_publication(
  self : RosActionEndpoints,
) -> @rtps.SedpEndpointData {
  self.cancel_goal_response_publication
}

///|
pub fn RosActionEndpoints::feedback_publication(
  self : RosActionEndpoints,
) -> @rtps.SedpEndpointData {
  self.feedback_publication
}

///|
pub fn RosActionEndpoints::status_publication(
  self : RosActionEndpoints,
) -> @rtps.SedpEndpointData {
  self.status_publication
}
