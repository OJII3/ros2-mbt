///|
test "ROS action parser splits goal, result, and feedback messages" {
  let action = parse_action(
    "example_interfaces",
    "Fibonacci",
    "# Goal\nint32 order\n---\n# Result\nint32[] sequence\n---\n# Feedback\nint32[] sequence",
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
    parse_action(
      "demo", "TooMany", "int32 value\n---\nint32 result\n---\n---",
    ) is Err(_),
  )
  assert_true(
    parse_action("demo", "Empty", "int32 value\n---\nint32 result") is Err(_),
  )
  let empty_sections = parse_action("demo", "Empty", "int32 value\n---\n---")
    .unwrap()
  assert_eq(empty_sections.result().fields().length(), 0)
  assert_eq(empty_sections.feedback().fields().length(), 0)
  let action = parse_action(
    "demo",
    "Separated",
    "string DELIMITER=\"---\"\n---\n# --- is a comment\nint32 result\n---\nint32 feedback",
  ).unwrap()
  assert_eq(action.goal().constants().length(), 1)
  assert_eq(action.result().fields().length(), 1)
  assert_eq(action.feedback().fields().length(), 1)
}

///|
test "ROS workspace generates action codecs with nested imports and hashes" {
  let workspace = MessageWorkspace::new()
  workspace.add_source(
    MessageSource::new(
      "demo_msgs",
      "msg",
      "Vector3",
      "float64 x\nfloat64 y\nfloat64 z",
    ).unwrap(),
  ).unwrap()
  workspace.add_source(
    MessageSource::new(
      "std_msgs", "msg", "Header", "uint32 seq\nstring frame_id",
    ).unwrap(),
  ).unwrap()
  workspace.add_import(
    MessageImport::new("std_msgs", "std_msgs/msg", "std").unwrap(),
  ).unwrap()
  let generated = workspace.generate_action_moonbit(
    "demo_msgs",
    "Move",
    "Vector3 target\n---\nint32 status\n---\nstd_msgs/Header header",
  ).unwrap()
  assert_true(generated.contains("\"std_msgs/msg\" @std"))
  assert_true(generated.contains("pub struct Move_Goal"))
  assert_true(generated.contains("target : Vector3"))
  assert_true(generated.contains("pub struct Move_Result"))
  assert_true(generated.contains("pub struct Move_Feedback"))
  assert_true(generated.contains("header : @std.Header"))
  assert_true(generated.contains("pub const Move_Goal_TYPE_HASH"))
  assert_true(generated.contains("pub const Move_Feedback_TYPE_HASH"))
}
