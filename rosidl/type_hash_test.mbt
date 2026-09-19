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

///|
test "ROS workspace service hash includes nested request and response types" {
  let workspace = MessageWorkspace::new()
  let vector = MessageSource::new(
    "demo_msgs",
    "msg",
    "Vector3",
    "float64 x\nfloat64 y\nfloat64 z",
  ).unwrap()
  workspace.add_source(vector).unwrap()
  let service = parse_service_with_types(
    "demo_msgs",
    "Transform",
    "Vector3 input\n---\nVector3 output",
    [MessageTypeReference::new("Vector3", "Vector3")],
  ).unwrap()
  assert_eq(
    workspace.service_type_hash(service),
    Ok(
      "RIHS01_fccf83d6b43e472bd0d662b34e95bf20785b6aad52cb6a0f030cd5935766cd5b",
    ),
  )
}

///|
test "ROS workspace type hash sorts multiple nested descriptions" {
  let workspace = MessageWorkspace::new()
  for name in ["A", "B"] {
    workspace.add_source(
      MessageSource::new(
        "demo_msgs",
        "msg",
        name,
        "int32 value",
      ).unwrap(),
    ).unwrap()
  }
  workspace.add_source(
    MessageSource::new(
      "demo_msgs",
      "msg",
      "Root",
      "B b\nA a",
    ).unwrap(),
  ).unwrap()
  assert_eq(
    workspace.type_hash("demo_msgs", "msg", "Root"),
    Ok(
      "RIHS01_19e2cc2e5e8ea923b52c7bc74ad202807d2a37fbadcf69060b2bf958fb2abf0a",
    ),
  )
}
