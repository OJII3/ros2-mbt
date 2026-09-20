///|
test "ROS action descriptor maps all five endpoints" {
  let action = RosAction::new("/fibonacci", "example_interfaces", "Fibonacci").unwrap()
  assert_eq(action.ros_name(), "/fibonacci")

  let send_goal = action.send_goal_service()
  assert_eq(send_goal.ros_name(), "/fibonacci/_action/send_goal")
  assert_eq(
    send_goal.dds_request_name(),
    "rq/fibonacci/_action/send_goalRequest",
  )
  assert_eq(
    send_goal.dds_response_name(),
    "rr/fibonacci/_action/send_goalReply",
  )
  assert_eq(
    send_goal.dds_request_type_name(),
    "example_interfaces::action::dds_::Fibonacci_SendGoal_Request_",
  )
  assert_eq(
    send_goal.dds_response_type_name(),
    "example_interfaces::action::dds_::Fibonacci_SendGoal_Response_",
  )

  let get_result = action.get_result_service()
  assert_eq(
    get_result.dds_request_name(),
    "rq/fibonacci/_action/get_resultRequest",
  )
  assert_eq(
    get_result.dds_response_name(),
    "rr/fibonacci/_action/get_resultReply",
  )
  assert_eq(
    get_result.dds_request_type_name(),
    "example_interfaces::action::dds_::Fibonacci_GetResult_Request_",
  )
  assert_eq(
    get_result.dds_response_type_name(),
    "example_interfaces::action::dds_::Fibonacci_GetResult_Response_",
  )

  let cancel_goal = action.cancel_goal_service()
  assert_eq(
    cancel_goal.dds_request_name(),
    "rq/fibonacci/_action/cancel_goalRequest",
  )
  assert_eq(
    cancel_goal.dds_request_type_name(),
    "action_msgs::srv::dds_::CancelGoal_Request_",
  )
  assert_eq(
    cancel_goal.dds_response_type_name(),
    "action_msgs::srv::dds_::CancelGoal_Response_",
  )

  let feedback = action.feedback_topic()
  assert_eq(feedback.ros_name(), "/fibonacci/_action/feedback")
  assert_eq(feedback.dds_name(), "rt/fibonacci/_action/feedback")
  assert_eq(
    feedback.dds_type_name(),
    "example_interfaces::action::dds_::Fibonacci_FeedbackMessage_",
  )

  let status = action.status_topic()
  assert_eq(status.ros_name(), "/fibonacci/_action/status")
  assert_eq(status.dds_name(), "rt/fibonacci/_action/status")
  assert_eq(status.dds_type_name(), "action_msgs::msg::dds_::GoalStatusArray_")
}

///|
test "ROS service default namespace remains srv" {
  let service = RosService::new(
    "/add_two_ints", "example_interfaces", "AddTwoInts",
  ).unwrap()
  assert_eq(
    service.dds_request_type_name(),
    "example_interfaces::srv::dds_::AddTwoInts_Request_",
  )
}
