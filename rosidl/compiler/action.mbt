///|
/// A parsed ROS action definition containing its goal, result, and feedback
/// message definitions.
pub struct ActionDefinition {
  package_name : String
  action_name : String
  goal : MessageDefinition
  result : MessageDefinition
  feedback : MessageDefinition
} derive(Eq, Debug)

///|
pub extend ActionDefinition with Eq::{not_equal, equal}

///|
pub extend ActionDefinition with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Create a validated ROS action definition.
pub fn ActionDefinition::new(
  package_name : String,
  action_name : String,
  goal : MessageDefinition,
  result : MessageDefinition,
  feedback : MessageDefinition,
) -> Result[ActionDefinition, String] {
  if !rosidl_identifier(package_name) || !rosidl_identifier(action_name) {
    return Err("ROS action package and type must be identifiers")
  }
  if !rosidl_action_message_identity(goal, package_name, action_name, "Goal") ||
    !rosidl_action_message_identity(result, package_name, action_name, "Result") ||
    !rosidl_action_message_identity(
      feedback, package_name, action_name, "Feedback",
    ) {
    return Err("ROS action message definitions have the wrong identity")
  }
  Ok({ package_name, action_name, goal, result, feedback, })
}

///|
fn rosidl_action_message_identity(
  definition : MessageDefinition,
  package_name : String,
  action_name : String,
  suffix : String,
) -> Bool {
  definition.package_name() == package_name &&
  definition.interface_namespace() == "action" &&
  definition.type_name() == action_name + "_" + suffix
}

///|
pub fn ActionDefinition::package_name(self : ActionDefinition) -> String {
  self.package_name
}

///|
pub fn ActionDefinition::action_name(self : ActionDefinition) -> String {
  self.action_name
}

///|
pub fn ActionDefinition::goal(self : ActionDefinition) -> MessageDefinition {
  self.goal
}

///|
pub fn ActionDefinition::result(self : ActionDefinition) -> MessageDefinition {
  self.result
}

///|
pub fn ActionDefinition::feedback(self : ActionDefinition) -> MessageDefinition {
  self.feedback
}

///|
/// Generate MoonBit codecs for an action's goal, result, and feedback
/// messages. ROS action service wrappers and transport are separate layers.
pub fn ActionDefinition::generate_moonbit(self : ActionDefinition) -> String {
  self.goal.generate_moonbit() +
  "\n\n" +
  self.result.generate_moonbit() +
  "\n\n" +
  self.feedback.generate_moonbit()
}

///|
/// Build the action-specific message types used by SendGoal, GetResult, and
/// feedback. The supplied MoonBit type names identify the imported UUID and
/// Time message types.
fn ActionDefinition::protocol_messages(
  self : ActionDefinition,
  uuid_moon_type : String,
  time_moon_type : String,
) -> Result[Array[MessageDefinition], String] {
  let uuid_ros_type = "unique_identifier_msgs/UUID"
  let time_ros_type = "builtin_interfaces/Time"
  let goal_name = self.goal.type_name()
  let result_name = self.result.type_name()
  let feedback_name = self.feedback.type_name()
  let uuid_reference = MessageTypeReference::new(uuid_ros_type, uuid_moon_type)
  let time_reference = MessageTypeReference::new(time_ros_type, time_moon_type)
  let goal_reference = MessageTypeReference::new(goal_name, goal_name)
  let result_reference = MessageTypeReference::new(result_name, result_name)
  let feedback_reference = MessageTypeReference::new(
    feedback_name, feedback_name,
  )
  let send_goal_request = match
    MessageDefinition::new_with_types(
      self.package_name,
      "action",
      self.action_name + "_SendGoal_Request",
      [
        MessageField::new(uuid_ros_type, "goal_id"),
        MessageField::new(goal_name, "goal"),
      ],
      [uuid_reference, goal_reference],
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let send_goal_response = match
    MessageDefinition::new_with_types(
      self.package_name,
      "action",
      self.action_name + "_SendGoal_Response",
      [
        MessageField::new("bool", "accepted"),
        MessageField::new(time_ros_type, "stamp"),
      ],
      [time_reference],
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let get_result_request = match
    MessageDefinition::new_with_types(
      self.package_name,
      "action",
      self.action_name + "_GetResult_Request",
      [MessageField::new(uuid_ros_type, "goal_id")],
      [uuid_reference],
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let get_result_response = match
    MessageDefinition::new_with_types(
      self.package_name,
      "action",
      self.action_name + "_GetResult_Response",
      [
        MessageField::new("int8", "status"),
        MessageField::new(result_name, "result"),
      ],
      [result_reference],
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let feedback_message = match
    MessageDefinition::new_with_types(
      self.package_name,
      "action",
      self.action_name + "_FeedbackMessage",
      [
        MessageField::new(uuid_ros_type, "goal_id"),
        MessageField::new(feedback_name, "feedback"),
      ],
      [uuid_reference, feedback_reference],
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok([
    send_goal_request, send_goal_response, get_result_request, get_result_response,
    feedback_message,
  ])
}

///|
/// Parse the three message sections of a ROS `.action` definition.
pub fn parse_action(
  package_name : String,
  action_name : String,
  source : String,
) -> Result[ActionDefinition, String] {
  parse_action_with_types(package_name, action_name, source, [])
}

///|
/// Parse a ROS `.action` definition with explicit nested message references.
pub fn parse_action_with_types(
  package_name : String,
  action_name : String,
  source : String,
  nested_types : Array[MessageTypeReference],
) -> Result[ActionDefinition, String] {
  let (goal_source, result_source, feedback_source) = match
    rosidl_action_sections(source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let goal = match
    parse_message_with_types(
      package_name,
      "action",
      action_name + "_Goal",
      goal_source,
      nested_types,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let result = match
    parse_message_with_types(
      package_name,
      "action",
      action_name + "_Result",
      result_source,
      nested_types,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let feedback = match
    parse_message_with_types(
      package_name,
      "action",
      action_name + "_Feedback",
      feedback_source,
      nested_types,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  ActionDefinition::new(package_name, action_name, goal, result, feedback)
}

///|
fn rosidl_action_sections(
  source : String,
) -> Result[(String, String, String), String] {
  let sections : FixedArray[String] = ["", "", ""]
  let mut section_index = 0
  for raw_line in source.split("\n") {
    if rosidl_trim(raw_line.to_owned()) == "---" {
      if section_index >= 2 {
        return Err("ROS action definitions must contain two --- separators")
      }
      section_index += 1
      continue
    }
    sections[section_index] = sections[section_index] +
      raw_line.to_owned() +
      "\n"
  }
  if section_index != 2 {
    return Err("ROS action definitions must contain two --- separators")
  }
  Ok((sections[0], sections[1], sections[2]))
}
