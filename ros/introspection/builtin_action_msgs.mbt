///|
fn builtin_action_msgs_message_source(type_name : String) -> String? {
  match type_name {
    "GoalInfo" =>
      Some(
        "unique_identifier_msgs/UUID goal_id\nbuiltin_interfaces/Time stamp\n",
      )
    "GoalStatus" =>
      Some(
        "int8 STATUS_UNKNOWN   = 0\nint8 STATUS_ACCEPTED  = 1\nint8 STATUS_EXECUTING = 2\nint8 STATUS_CANCELING = 3\nint8 STATUS_SUCCEEDED = 4\nint8 STATUS_CANCELED  = 5\nint8 STATUS_ABORTED   = 6\nGoalInfo goal_info\nint8 status\n",
      )
    "GoalStatusArray" => Some("GoalStatus[] status_list\n")
    _ => None
  }
}
