///|
test "action GoalStatusArray CDR round trip preserves aligned entries" {
  let first_goal = @action_msgs.RosActionGoalInfo::new(
    Bytes::from_array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]),
    12,
    345U,
  ).unwrap()
  let second_goal = @action_msgs.RosActionGoalInfo::new(
    Bytes::from_array([16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]),
    -2,
    999U,
  ).unwrap()
  let status_list = @action_msgs.RosActionGoalStatusArray::new([
    @action_msgs.RosActionGoalStatus::new(
      first_goal,
      @action_msgs.ROS_ACTION_GOAL_STATUS_ACCEPTED,
    ).unwrap(),
    @action_msgs.RosActionGoalStatus::new(
      second_goal,
      @action_msgs.ROS_ACTION_GOAL_STATUS_CANCELED,
    ).unwrap(),
  ])

  let parsed = @action_msgs.RosActionGoalStatusArray::from_cdr_bytes(
    status_list.to_cdr_bytes(),
  ).unwrap()
  assert_eq(parsed, status_list)
}

///|
test "CancelGoal request and response CDR round trip" {
  let goal_info = @action_msgs.RosActionGoalInfo::new(
    Bytes::from_array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]),
    7,
    8U,
  ).unwrap()
  let request = @action_msgs.RosCancelGoalRequest::new(goal_info)
  assert_eq(
    @action_msgs.RosCancelGoalRequest::from_cdr_bytes(request.to_cdr_bytes()).unwrap(),
    request,
  )

  let response = @action_msgs.RosCancelGoalResponse::new(0, [goal_info]).unwrap()
  assert_eq(
    @action_msgs.RosCancelGoalResponse::from_cdr_bytes(response.to_cdr_bytes()).unwrap(),
    response,
  )
}

///|
test "action control CDR codecs reject malformed payloads" {
  assert_true(
    @action_msgs.RosActionGoalInfo::new(Bytes::from_array([1, 2]), 0, 0U)
    is Err(_),
  )
  let goal_info = @action_msgs.RosActionGoalInfo::new(
    Bytes::from_array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]),
    0,
    0U,
  ).unwrap()
  assert_true(@action_msgs.RosActionGoalStatus::new(goal_info, 128) is Err(_))
  assert_false(
    @action_msgs.RosActionGoalStatus::new(
      goal_info,
      @action_msgs.ROS_ACTION_GOAL_STATUS_ACCEPTED,
    )
    .unwrap()
    .is_terminal(),
  )
  assert_false(
    @action_msgs.RosActionGoalStatus::new(
      goal_info,
      @action_msgs.ROS_ACTION_GOAL_STATUS_EXECUTING,
    )
    .unwrap()
    .is_terminal(),
  )
  assert_false(
    @action_msgs.RosActionGoalStatus::new(
      goal_info,
      @action_msgs.ROS_ACTION_GOAL_STATUS_CANCELING,
    )
    .unwrap()
    .is_terminal(),
  )
  for
    status in [
      @action_msgs.ROS_ACTION_GOAL_STATUS_SUCCEEDED,
      @action_msgs.ROS_ACTION_GOAL_STATUS_CANCELED,
      @action_msgs.ROS_ACTION_GOAL_STATUS_ABORTED,
    ] {
    assert_true(
      @action_msgs.RosActionGoalStatus::new(goal_info, status)
      .unwrap()
      .is_terminal(),
    )
  }
  assert_true(
    @action_msgs.RosActionGoalStatusArray::from_cdr_bytes(
      Bytes::from_array([0, 1, 0, 0, 255, 255, 255, 255]),
    )
    is Err(_),
  )
  assert_true(
    @action_msgs.RosCancelGoalResponse::from_cdr_bytes(
      Bytes::from_array([0, 1, 0, 0, 0, 1, 0, 0, 0]),
    )
    is Err(_),
  )
}
