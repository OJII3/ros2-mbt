///|
/// Standard status values from `action_msgs/msg/GoalStatus`.
pub const ROS_ACTION_GOAL_STATUS_UNKNOWN : Int = 0

///|
pub const ROS_ACTION_GOAL_STATUS_ACCEPTED : Int = 1

///|
pub const ROS_ACTION_GOAL_STATUS_EXECUTING : Int = 2

///|
pub const ROS_ACTION_GOAL_STATUS_CANCELING : Int = 3

///|
pub const ROS_ACTION_GOAL_STATUS_SUCCEEDED : Int = 4

///|
pub const ROS_ACTION_GOAL_STATUS_CANCELED : Int = 5

///|
pub const ROS_ACTION_GOAL_STATUS_ABORTED : Int = 6

///|
/// The goal identifier and timestamp carried by ROS 2 action control messages.
pub struct RosActionGoalInfo {
  goal_id : Bytes
  stamp_sec : Int
  stamp_nanosec : UInt
} derive(Eq, Debug)

///|
pub fn RosActionGoalInfo::new(
  goal_id : Bytes,
  stamp_sec : Int,
  stamp_nanosec : UInt,
) -> Result[RosActionGoalInfo, String] {
  if goal_id.length() != 16 {
    return Err("an action goal ID must contain exactly 16 bytes")
  }
  Ok({ goal_id, stamp_sec, stamp_nanosec, })
}

///|
pub fn RosActionGoalInfo::goal_id(self : RosActionGoalInfo) -> Bytes {
  self.goal_id
}

///|
pub fn RosActionGoalInfo::stamp_sec(self : RosActionGoalInfo) -> Int {
  self.stamp_sec
}

///|
pub fn RosActionGoalInfo::stamp_nanosec(self : RosActionGoalInfo) -> UInt {
  self.stamp_nanosec
}

///|
/// A goal and its current status in `action_msgs/msg/GoalStatus`.
pub struct RosActionGoalStatus {
  goal_info : RosActionGoalInfo
  status : Int
} derive(Eq, Debug)

///|
pub fn RosActionGoalStatus::new(
  goal_info : RosActionGoalInfo,
  status : Int,
) -> Result[RosActionGoalStatus, String] {
  if status < -128 || status > 127 {
    return Err("an action goal status must fit in int8")
  }
  Ok({ goal_info, status, })
}

///|
pub fn RosActionGoalStatus::goal_info(
  self : RosActionGoalStatus,
) -> RosActionGoalInfo {
  self.goal_info
}

///|
pub fn RosActionGoalStatus::status(self : RosActionGoalStatus) -> Int {
  self.status
}

///|
/// Whether this goal status represents a completed action goal.
pub fn RosActionGoalStatus::is_terminal(self : RosActionGoalStatus) -> Bool {
  self.status == ROS_ACTION_GOAL_STATUS_SUCCEEDED ||
  self.status == ROS_ACTION_GOAL_STATUS_CANCELED ||
  self.status == ROS_ACTION_GOAL_STATUS_ABORTED
}

///|
/// The status sequence published on a ROS 2 action's status topic.
pub struct RosActionGoalStatusArray {
  status_list : Array[RosActionGoalStatus]
} derive(Eq, Debug)

///|
pub fn RosActionGoalStatusArray::new(
  status_list : Array[RosActionGoalStatus],
) -> RosActionGoalStatusArray {
  { status_list, }
}

///|
pub fn RosActionGoalStatusArray::status_list(
  self : RosActionGoalStatusArray,
) -> Array[RosActionGoalStatus] {
  self.status_list
}

///|
/// Serialize `action_msgs/msg/GoalStatusArray` using ROS 2 CDR.
pub fn RosActionGoalStatusArray::to_cdr_bytes(
  self : RosActionGoalStatusArray,
) -> Bytes {
  let writer = @cdr.Writer::new()
  writer.write_u32(self.status_list.length().reinterpret_as_uint())
  for status in self.status_list {
    ros_action_goal_info_write(writer, status.goal_info)
    writer.write_i8(status.status)
  }
  writer.to_bytes()
}

///|
/// Parse `action_msgs/msg/GoalStatusArray` from ROS 2 CDR.
pub fn RosActionGoalStatusArray::from_cdr_bytes(
  input : Bytes,
) -> Result[RosActionGoalStatusArray, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let count = match reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if count < 0 || count > reader.remaining() / 25 {
    return Err("invalid GoalStatusArray status_list sequence length")
  }
  let status_list : Array[RosActionGoalStatus] = []
  for _ in 0..<count {
    let goal_info = match ros_action_goal_info_read(reader) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let status = match reader.read_i8() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    status_list.push({ goal_info, status, })
  }
  if !reader.remaining_is_zero_padding(4) {
    return Err("trailing bytes after GoalStatusArray")
  }
  Ok({ status_list, })
}

///|
/// A request for the standard `action_msgs/srv/CancelGoal` service.
pub struct RosCancelGoalRequest {
  goal_info : RosActionGoalInfo
} derive(Eq, Debug)

///|
pub fn RosCancelGoalRequest::new(
  goal_info : RosActionGoalInfo,
) -> RosCancelGoalRequest {
  { goal_info, }
}

///|
pub fn RosCancelGoalRequest::goal_info(
  self : RosCancelGoalRequest,
) -> RosActionGoalInfo {
  self.goal_info
}

///|
/// Serialize `action_msgs/srv/CancelGoal`'s request.
pub fn RosCancelGoalRequest::to_cdr_bytes(self : RosCancelGoalRequest) -> Bytes {
  let writer = @cdr.Writer::new()
  ros_action_goal_info_write(writer, self.goal_info)
  writer.to_bytes()
}

///|
/// Parse `action_msgs/srv/CancelGoal`'s request.
pub fn RosCancelGoalRequest::from_cdr_bytes(
  input : Bytes,
) -> Result[RosCancelGoalRequest, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let goal_info = match ros_action_goal_info_read(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if !reader.remaining_is_zero_padding(4) {
    return Err("trailing bytes after CancelGoal request")
  }
  Ok({ goal_info, })
}

///|
/// A response from the standard `action_msgs/srv/CancelGoal` service.
pub struct RosCancelGoalResponse {
  return_code : Int
  goals_canceling : Array[RosActionGoalInfo]
} derive(Eq, Debug)

///|
pub fn RosCancelGoalResponse::new(
  return_code : Int,
  goals_canceling : Array[RosActionGoalInfo],
) -> Result[RosCancelGoalResponse, String] {
  if return_code < -128 || return_code > 127 {
    return Err("a CancelGoal return code must fit in int8")
  }
  Ok({ return_code, goals_canceling, })
}

///|
pub fn RosCancelGoalResponse::return_code(self : RosCancelGoalResponse) -> Int {
  self.return_code
}

///|
pub fn RosCancelGoalResponse::goals_canceling(
  self : RosCancelGoalResponse,
) -> Array[RosActionGoalInfo] {
  self.goals_canceling
}

///|
/// Serialize `action_msgs/srv/CancelGoal`'s response.
pub fn RosCancelGoalResponse::to_cdr_bytes(
  self : RosCancelGoalResponse,
) -> Bytes {
  let writer = @cdr.Writer::new()
  writer.write_i8(self.return_code)
  writer.write_u32(self.goals_canceling.length().reinterpret_as_uint())
  for goal_info in self.goals_canceling {
    ros_action_goal_info_write(writer, goal_info)
  }
  writer.to_bytes()
}

///|
/// Parse `action_msgs/srv/CancelGoal`'s response.
pub fn RosCancelGoalResponse::from_cdr_bytes(
  input : Bytes,
) -> Result[RosCancelGoalResponse, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let return_code = match reader.read_i8() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let count = match reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if count < 0 || count > reader.remaining() / 24 {
    return Err("invalid CancelGoal goals_canceling sequence length")
  }
  let goals_canceling : Array[RosActionGoalInfo] = []
  for _ in 0..<count {
    match ros_action_goal_info_read(reader) {
      Ok(value) => goals_canceling.push(value)
      Err(message) => return Err(message)
    }
  }
  if !reader.remaining_is_zero_padding(4) {
    return Err("trailing bytes after CancelGoal response")
  }
  Ok({ return_code, goals_canceling, })
}

///|
fn ros_action_goal_info_write(
  writer : @cdr.Writer,
  goal_info : RosActionGoalInfo,
) -> Unit {
  writer.write_byte_array(goal_info.goal_id)
  writer.write_i32(goal_info.stamp_sec)
  writer.write_u32(goal_info.stamp_nanosec)
}

///|
fn ros_action_goal_info_read(
  reader : @cdr.Reader,
) -> Result[RosActionGoalInfo, String] {
  let goal_id = match reader.read_byte_array(16) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let stamp_sec = match reader.read_i32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let stamp_nanosec = match reader.read_u32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ goal_id, stamp_sec, stamp_nanosec, })
}
