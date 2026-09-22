///|
test "ROS names map to DDS topic prefixes" {
  assert_eq(@names.ros_topic_to_dds("/chatter"), Ok("rt/chatter"))
  assert_eq(@names.ros_topic_to_dds("status"), Ok("rt/status"))
  assert_eq(
    @names.ros_service_request_to_dds("/add_two_ints"),
    Ok("rq/add_two_intsRequest"),
  )
  assert_eq(
    @names.ros_service_response_to_dds("/add_two_ints"),
    Ok("rr/add_two_intsReply"),
  )
}

///|
test "ROS interface names map to DDS type names" {
  assert_eq(
    @names.ros_type_to_dds("std_msgs", "msg", "String"),
    Ok("std_msgs::msg::dds_::String_"),
  )
  assert_eq(
    @names.ros_type_path_to_dds("geometry_msgs/msg/Twist"),
    Ok("geometry_msgs::msg::dds_::Twist_"),
  )
}

///|
test "ROS name helpers reject empty and malformed names" {
  assert_true(@names.ros_topic_to_dds("") is Err(_))
  assert_true(@names.ros_type_path_to_dds("std_msgs/msg") is Err(_))
  assert_true(@names.ros_type_to_dds("", "msg", "String") is Err(_))
}
