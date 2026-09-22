///|
/// ROS 2 action endpoints mapped to their DDS service and topic identities.
pub struct RosAction {
  ros_name : String
  send_goal_service : RosService
  get_result_service : RosService
  cancel_goal_service : RosService
  feedback_topic : RosTopic
  status_topic : RosTopic
}

///|
/// Create a ROS action descriptor from its action name and interface type.
pub fn RosAction::new(
  ros_name : String,
  package_name : String,
  action_name : String,
) -> Result[RosAction, String] {
  let send_goal_service = match
    RosService::new_with_interface_namespace(
      ros_name + "/_action/send_goal",
      package_name,
      "action",
      action_name + "_SendGoal",
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let get_result_service = match
    RosService::new_with_interface_namespace(
      ros_name + "/_action/get_result",
      package_name,
      "action",
      action_name + "_GetResult",
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let cancel_goal_service = match
    RosService::new_with_interface_namespace(
      ros_name + "/_action/cancel_goal",
      "action_msgs",
      "srv",
      "CancelGoal",
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let feedback_topic = match
    RosTopic::new(
      ros_name + "/_action/feedback",
      package_name,
      "action",
      action_name + "_FeedbackMessage",
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let status_topic = match
    RosTopic::new(
      ros_name + "/_action/status",
      "action_msgs",
      "msg",
      "GoalStatusArray",
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({
    ros_name,
    send_goal_service,
    get_result_service,
    cancel_goal_service,
    feedback_topic,
    status_topic,
  })
}

///|
/// Return the ROS action name.
pub fn RosAction::ros_name(self : RosAction) -> String {
  self.ros_name
}

///|
/// Return the send-goal service descriptor.
pub fn RosAction::send_goal_service(self : RosAction) -> RosService {
  self.send_goal_service
}

///|
/// Return the get-result service descriptor.
pub fn RosAction::get_result_service(self : RosAction) -> RosService {
  self.get_result_service
}

///|
/// Return the cancel-goal service descriptor.
pub fn RosAction::cancel_goal_service(self : RosAction) -> RosService {
  self.cancel_goal_service
}

///|
/// Return the feedback topic descriptor.
pub fn RosAction::feedback_topic(self : RosAction) -> RosTopic {
  self.feedback_topic
}

///|
/// Return the status topic descriptor.
pub fn RosAction::status_topic(self : RosAction) -> RosTopic {
  self.status_topic
}
