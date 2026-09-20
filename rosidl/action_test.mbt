///|
test "ROS action parser splits goal, result, and feedback messages" {
  let action = parse_action(
    "example_interfaces", "Fibonacci", "# Goal\nint32 order\n---\n# Result\nint32[] sequence\n---\n# Feedback\nint32[] sequence",
  ).unwrap()
  assert_eq(action.package_name(), "example_interfaces")
  assert_eq(action.action_name(), "Fibonacci")
  assert_eq(action.goal().type_name(), "Fibonacci_Goal")
  assert_eq(action.result().type_name(), "Fibonacci_Result")
  assert_eq(action.feedback().type_name(), "Fibonacci_Feedback")
  assert_eq(action.goal().interface_namespace(), "action")
  assert_eq(action.goal().fields()[0].name(), "order")
  assert_eq(
    action.result().fields()[0].collection(),
    MessageFieldCollection::Sequence,
  )
  let generated = action.generate_moonbit()
  assert_true(generated.contains("pub struct Fibonacci_Goal"))
  assert_true(generated.contains("pub struct Fibonacci_Result"))
  assert_true(generated.contains("pub struct Fibonacci_Feedback"))
  assert_true(generated.contains("writer.write_i32(self.order)"))
  assert_true(generated.contains("pub const Fibonacci_Goal_TYPE_HASH"))
}

///|
test "ROS action parser requires exactly two standalone separators" {
  assert_true(
    parse_action("demo", "TooMany", "int32 value\n---\nint32 result\n---\n---")
    is Err(_),
  )
  assert_true(
    parse_action("demo", "Empty", "int32 value\n---\nint32 result") is Err(_),
  )
  let empty_sections = parse_action("demo", "Empty", "int32 value\n---\n---").unwrap()
  assert_eq(empty_sections.result().fields().length(), 0)
  assert_eq(empty_sections.feedback().fields().length(), 0)
  let action = parse_action(
    "demo", "Separated", "string DELIMITER=\"---\"\n---\n# --- is a comment\nint32 result\n---\nint32 feedback",
  ).unwrap()
  assert_eq(action.goal().constants().length(), 1)
  assert_eq(action.result().fields().length(), 1)
  assert_eq(action.feedback().fields().length(), 1)
}

///|
test "ROS workspace generates action codecs with nested imports and hashes" {
  let workspace = MessageWorkspace::new()
  workspace
  .add_source(
    MessageSource::new(
      "demo_msgs", "msg", "Vector3", "float64 x\nfloat64 y\nfloat64 z",
    ).unwrap(),
  )
  .unwrap()
  workspace
  .add_source(
    MessageSource::new(
      "std_msgs", "msg", "Header", "uint32 seq\nstring frame_id",
    ).unwrap(),
  )
  .unwrap()
  workspace
  .add_source(
    MessageSource::new(
      "unique_identifier_msgs", "msg", "UUID", "uint8[16] uuid",
    ).unwrap(),
  )
  .unwrap()
  workspace
  .add_source(
    MessageSource::new(
      "builtin_interfaces", "msg", "Time", "int32 sec\nuint32 nanosec",
    ).unwrap(),
  )
  .unwrap()
  workspace
  .add_import(MessageImport::new("std_msgs", "std_msgs/msg", "std").unwrap())
  .unwrap()
  workspace
  .add_import(
    MessageImport::new(
      "unique_identifier_msgs", "unique_identifier_msgs/msg", "unique",
    ).unwrap(),
  )
  .unwrap()
  workspace
  .add_import(
    MessageImport::new(
      "builtin_interfaces", "builtin_interfaces/msg", "builtin",
    ).unwrap(),
  )
  .unwrap()
  let generated = workspace
    .generate_action_moonbit(
      "demo_msgs", "Move", "Vector3 target\n---\nint32 status\n---\nstd_msgs/Header header",
    )
    .unwrap()
  assert_true(generated.contains("\"std_msgs/msg\" @std"))
  assert_true(generated.contains("pub struct Move_Goal"))
  assert_true(generated.contains("target : Vector3"))
  assert_true(generated.contains("pub struct Move_Result"))
  assert_true(generated.contains("pub struct Move_Feedback"))
  assert_true(generated.contains("pub struct Move_SendGoal_Request"))
  assert_true(generated.contains("pub struct Move_SendGoal_Response"))
  assert_true(generated.contains("pub struct Move_GetResult_Request"))
  assert_true(generated.contains("pub struct Move_GetResult_Response"))
  assert_true(generated.contains("pub struct Move_FeedbackMessage"))
  assert_true(generated.contains("header : @std.Header"))
  assert_true(generated.contains("goal_id : @unique.UUID"))
  assert_true(generated.contains("stamp : @builtin.Time"))
  assert_true(generated.contains("pub const Move_Goal_TYPE_HASH"))
  assert_true(generated.contains("pub const Move_Feedback_TYPE_HASH"))
  assert_true(generated.contains("pub const Move_SendGoal_Request_TYPE_HASH"))
  assert_true(generated.contains("pub const Move_FeedbackMessage_TYPE_HASH"))
}

///|
test "ROS action protocol message hashes match Jazzy Fibonacci" {
  let workspace = MessageWorkspace::new()
  workspace
  .add_source(
    MessageSource::new(
      "unique_identifier_msgs", "msg", "UUID", "uint8[16] uuid",
    ).unwrap(),
  )
  .unwrap()
  workspace
  .add_source(
    MessageSource::new(
      "builtin_interfaces", "msg", "Time", "int32 sec\nuint32 nanosec",
    ).unwrap(),
  )
  .unwrap()
  workspace
  .add_import(
    MessageImport::new(
      "unique_identifier_msgs", "unique_identifier_msgs/msg", "unique",
    ).unwrap(),
  )
  .unwrap()
  workspace
  .add_import(
    MessageImport::new(
      "builtin_interfaces", "builtin_interfaces/msg", "builtin",
    ).unwrap(),
  )
  .unwrap()
  let generated = workspace
    .generate_action_moonbit(
      "example_interfaces", "Fibonacci", "int32 order\n---\nint32[] sequence\n---\nint32[] sequence",
    )
    .unwrap()
  assert_true(
    generated.contains(
      "pub const Fibonacci_Goal_TYPE_HASH : String = \"RIHS01_226cb437e4355dcd3e914f930382a3b0cc1da81545bd319ed554e95a03255f51\"",
    ),
  )
  assert_true(
    generated.contains(
      "pub const Fibonacci_Result_TYPE_HASH : String = \"RIHS01_fea81394f25aa4502217953f1a021fb750e79c10bbd43f13dd94632da6569649\"",
    ),
  )
  assert_true(
    generated.contains(
      "pub const Fibonacci_Feedback_TYPE_HASH : String = \"RIHS01_2b12e37361da6f408d4c85bc24a18de64333f29082f2ca34b5ee33dc4c8b42a9\"",
    ),
  )
  assert_true(
    generated.contains(
      "pub const Fibonacci_SendGoal_Request_TYPE_HASH : String = \"RIHS01_3d088942b413247db536576f0286768c6be8fcd5d0c9a5d544f359fba090a238\"",
    ),
  )
  assert_true(
    generated.contains(
      "pub const Fibonacci_SendGoal_Response_TYPE_HASH : String = \"RIHS01_d8c07bb3d5b766fe4b43159c9a5222af5214e2fcc29229b991d826166c512be1\"",
    ),
  )
  assert_true(
    generated.contains(
      "pub const Fibonacci_GetResult_Request_TYPE_HASH : String = \"RIHS01_c8a4f5e7d13b81286ee1043e2ecd084281cecf1ff06aaa799464f5f15479f003\"",
    ),
  )
  assert_true(
    generated.contains(
      "pub const Fibonacci_GetResult_Response_TYPE_HASH : String = \"RIHS01_6021dc98ab9b4bbe395e48aa4de81ee5f68eb570f88358affcc648146668b24f\"",
    ),
  )
  assert_true(
    generated.contains(
      "pub const Fibonacci_FeedbackMessage_TYPE_HASH : String = \"RIHS01_c1de71afd52e49a89c53d8262366884185bc0a02f78ce051c4e46b0a7fe59bb2\"",
    ),
  )
}

///|
test "ROS CancelGoal request and response hashes match their nested messages" {
  let workspace = MessageWorkspace::new()
  for
    source in [
      MessageSource::new(
        "unique_identifier_msgs", "msg", "UUID", "uint8[16] uuid",
      ),
      MessageSource::new(
        "builtin_interfaces", "msg", "Time", "int32 sec\nuint32 nanosec",
      ),
      MessageSource::new(
        "action_msgs", "msg", "GoalInfo", "unique_identifier_msgs/UUID goal_id\nbuiltin_interfaces/Time stamp",
      ),
    ] {
    match source {
      Ok(value) => assert_true(workspace.add_source(value) is Ok(_))
      Err(message) => fail(message)
    }
  }
  assert_true(
    workspace.add_import(
      MessageImport::new(
        "unique_identifier_msgs", "unique_identifier_msgs/msg", "unique",
      ).unwrap(),
    )
    is Ok(_),
  )
  assert_true(
    workspace.add_import(
      MessageImport::new(
        "builtin_interfaces", "builtin_interfaces/msg", "builtin",
      ).unwrap(),
    )
    is Ok(_),
  )
  let service = parse_service_with_types(
    "action_msgs",
    "CancelGoal",
    "GoalInfo goal_info\n---\nint8 return_code\nGoalInfo[] goals_canceling",
    [MessageTypeReference::new("GoalInfo", "GoalInfo")],
  ).unwrap()
  let request_hash = match
    workspace.type_hash_for_definition(service.request()) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let response_hash = match
    workspace.type_hash_for_definition(service.response()) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(
    request_hash, "RIHS01_3d3c84653c1f96918086887e1dcb236faec88b81a5b14fd4cf4840065bcdf8af",
  )
  assert_eq(
    response_hash, "RIHS01_35e682cf3f510e83c70a82a4aac888496dedee56773bf9d8e5e0aa81f9e1c960",
  )
}

///|
test "ROS Jazzy GoalStatusArray hash includes its nested message definitions" {
  let workspace = MessageWorkspace::new()
  for
    source in [
      MessageSource::new(
        "action_msgs", "msg", "GoalStatusArray", "GoalStatus[] status_list",
      ),
      MessageSource::new(
        "action_msgs", "msg", "GoalStatus", "int8 STATUS_UNKNOWN=0\nint8 STATUS_ACCEPTED=1\nint8 STATUS_EXECUTING=2\nint8 STATUS_CANCELING=3\nint8 STATUS_SUCCEEDED=4\nint8 STATUS_CANCELED=5\nint8 STATUS_ABORTED=6\nGoalInfo goal_info\nint8 status",
      ),
      MessageSource::new(
        "action_msgs", "msg", "GoalInfo", "unique_identifier_msgs/UUID goal_id\nbuiltin_interfaces/Time stamp",
      ),
      MessageSource::new(
        "builtin_interfaces", "msg", "Time", "int32 sec\nuint32 nanosec",
      ),
      MessageSource::new(
        "unique_identifier_msgs", "msg", "UUID", "uint8[16] uuid",
      ),
    ] {
    match source {
      Ok(value) => assert_true(workspace.add_source(value) is Ok(_))
      Err(message) => fail(message)
    }
  }
  workspace
  .add_import(
    MessageImport::new(
      "builtin_interfaces", "builtin_interfaces/msg", "builtin",
    ).unwrap(),
  )
  .unwrap()
  workspace
  .add_import(
    MessageImport::new(
      "unique_identifier_msgs", "unique_identifier_msgs/msg", "unique",
    ).unwrap(),
  )
  .unwrap()
  let hash = match
    workspace.type_hash("action_msgs", "msg", "GoalStatusArray") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(
    hash, "RIHS01_6c1684b00f177d37438febe6e709fc4e2b0d4248dca4854946f9ed8b30cda83e",
  )
}
