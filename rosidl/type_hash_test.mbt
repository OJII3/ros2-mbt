///|
test "ROS primitive message type hash matches the RIHS01 reference" {
  let definition = match
    parse_message("std_msgs", "msg", "String", "string data") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(
    definition.type_hash(),
    Ok(
      "RIHS01_df668c740482bbd48fb39d76a70dfd4bd59db1288021743503259e948f6b1a18",
    ),
  )
}

///|
test "ROS workspace type hash includes sorted nested message descriptions" {
  let workspace = MessageWorkspace::new()
  let vector = match
    MessageSource::new(
      "demo_msgs", "msg", "Vector3", "float64 x\nfloat64 y\nfloat64 z",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let pose = match
    MessageSource::new("demo_msgs", "msg", "Pose", "Vector3 position") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_true(workspace.add_source(vector) is Ok(_))
  assert_true(workspace.add_source(pose) is Ok(_))
  assert_eq(
    workspace.type_hash("demo_msgs", "msg", "Pose"),
    Ok(
      "RIHS01_2dfc887d6b11780ee8fe04e575a313ee259383ad7e4193a3d0bffc6db3d8f328",
    ),
  )
  let generated = match workspace.generate_moonbit("demo_msgs", "msg") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_true(
    generated.contains(
      "pub const Pose_TYPE_HASH : String = \"RIHS01_2dfc887d6b11780ee8fe04e575a313ee259383ad7e4193a3d0bffc6db3d8f328\"",
    ),
  )
}

///|
test "ROS primitive type hash rejects unresolved nested fields" {
  let definition = match
    parse_message_with_types(
      "demo_msgs",
      "msg",
      "Pose",
      "Vector3 position",
      [MessageTypeReference::new("Vector3", "Vector3")],
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_true(definition.type_hash() is Err(_))
}
