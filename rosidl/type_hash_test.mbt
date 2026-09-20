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
test "ROS bounded string type hashes use bounded string IDs and capacity" {
  let definition = parse_message(
    "demo",
    "msg",
    "BoundedStrings",
    "string<=8 value\nstring<=8[2] fixed\nstring<=8[<=3] bounded\nstring<=8[] sequence",
  ).unwrap()
  assert_eq(
    definition.type_hash(),
    Ok(
      "RIHS01_3b11e8a626ea93c8ea2430873f1740becdac3d3d2400f6d1ac97594ccf5463aa",
    ),
  )
}

///|
test "ROS wide-string type hashes use their own type IDs" {
  let wide = parse_message("demo", "msg", "Wide", "wstring data").unwrap()
  assert_eq(
    wide.type_hash(),
    Ok(
      "RIHS01_8203b3c357d38a350de9133031fb7c6af58260768a32c88dd234cc6452965133",
    ),
  )
  let bounded = parse_message(
    "demo", "msg", "BoundedWide", "wstring<=2 value",
  ).unwrap()
  assert_eq(
    bounded.type_hash(),
    Ok(
      "RIHS01_67db191861cdc89fd27d4061d6940df30704950eff8d6c7a9673cd05f96e596a",
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
test "ROS workspace generates nested service codecs and type hashes" {
  let workspace = MessageWorkspace::new()
  workspace.add_source(
    MessageSource::new(
      "demo_msgs",
      "msg",
      "Vector3",
      "float64 x\nfloat64 y\nfloat64 z",
    ).unwrap(),
  ).unwrap()
  let source = "Vector3 input\n---\nVector3 output"
  let service = parse_service_with_types(
    "demo_msgs",
    "Transform",
    source,
    [MessageTypeReference::new("Vector3", "Vector3")],
  ).unwrap()
  let request_hash = workspace.type_hash_for_definition(service.request()).unwrap()
  let response_hash = workspace.type_hash_for_definition(service.response()).unwrap()
  let service_hash = workspace.service_type_hash(service).unwrap()
  let generated = workspace.generate_service_moonbit(
    "demo_msgs", "Transform", source,
  ).unwrap()
  assert_true(generated.contains("pub struct Transform_Request"))
  assert_true(generated.contains("input : Vector3"))
  assert_true(generated.contains("pub struct Transform_Response"))
  assert_true(generated.contains("output : Vector3"))
  assert_true(
    generated.contains(
      "pub const Transform_Request_TYPE_HASH : String = \"" +
        request_hash + "\"",
    ),
  )
  assert_true(
    generated.contains(
      "pub const Transform_Response_TYPE_HASH : String = \"" +
        response_hash + "\"",
    ),
  )
  assert_true(
    generated.contains(
      "pub const Transform_TYPE_HASH : String = \"" + service_hash + "\"",
    ),
  )
}

///|
test "ROS workspace service generation imports external nested message types" {
  let workspace = MessageWorkspace::new()
  workspace.add_source(
    MessageSource::new(
      "std_msgs",
      "msg",
      "Header",
      "uint32 seq\nstring frame_id",
    ).unwrap(),
  ).unwrap()
  workspace.add_import(
    MessageImport::new("std_msgs", "std_msgs/msg", "std").unwrap(),
  ).unwrap()
  let generated = workspace.generate_service_moonbit(
    "demo_msgs",
    "Stamped",
    "std_msgs/Header header\n---\nstd_msgs/Header header",
  ).unwrap()
  assert_true(generated.contains("\"std_msgs/msg\" @std"))
  assert_true(generated.contains("header : @std.Header"))
  assert_true(generated.contains("pub const Stamped_Request_TYPE_HASH"))
  assert_true(generated.contains("pub const Stamped_TYPE_HASH"))
}

///|
test "ROS workspace service generation preserves primitive type hashes" {
  let workspace = MessageWorkspace::new()
  let generated = workspace.generate_service_moonbit(
    "example_interfaces",
    "AddTwoInts",
    "int64 a\nint64 b\n---\nint64 sum",
  ).unwrap()
  assert_eq(generated.split("pub const AddTwoInts_TYPE_HASH").length(), 2)
  assert_true(
    generated.contains(
      "pub const AddTwoInts_TYPE_HASH : String = \"RIHS01_baab5d12c15b0dbfdde3e778fa22481c0ef1c02268debebacff3ef350edce27e\"",
    ),
  )
}

///|
test "ROS parameter service request and response RIHS01 hashes" {
  let workspace = MessageWorkspace::new()
  workspace.add_source(
    MessageSource::new(
      "rcl_interfaces",
      "msg",
      "ParameterValue",
      "uint8 PARAMETER_NOT_SET=0\nuint8 PARAMETER_BOOL=1\nuint8 PARAMETER_INTEGER=2\nuint8 PARAMETER_DOUBLE=3\nuint8 PARAMETER_STRING=4\nuint8 PARAMETER_BYTE_ARRAY=5\nuint8 PARAMETER_BOOL_ARRAY=6\nuint8 PARAMETER_INTEGER_ARRAY=7\nuint8 PARAMETER_DOUBLE_ARRAY=8\nuint8 PARAMETER_STRING_ARRAY=9\nuint8 type\nbool bool_value\nint64 integer_value\nfloat64 double_value\nstring string_value\nbyte[] byte_array_value\nbool[] bool_array_value\nint64[] integer_array_value\nfloat64[] double_array_value\nstring[] string_array_value",
    ).unwrap(),
  ).unwrap()
  workspace.add_source(
    MessageSource::new(
      "rcl_interfaces",
      "msg",
      "Parameter",
      "string name\nParameterValue value",
    ).unwrap(),
  ).unwrap()
  workspace.add_source(
    MessageSource::new(
      "rcl_interfaces",
      "msg",
      "SetParametersResult",
      "bool successful\nstring reason",
    ).unwrap(),
  ).unwrap()
  workspace.add_source(
    MessageSource::new(
      "rcl_interfaces",
      "msg",
      "ListParametersResult",
      "string[] names\nstring[] prefixes",
    ).unwrap(),
  ).unwrap()
  let service = parse_service_with_types(
    "rcl_interfaces",
    "GetParameters",
    "string[] names\n---\nParameterValue[] values",
    [
      MessageTypeReference::new("ParameterValue", "ParameterValue"),
    ],
  ).unwrap()
  assert_eq(
    workspace.type_hash_for_definition(service.request()),
    Ok(
      "RIHS01_135a9e1c3d7cebef792f6687d7ddf99949b21a0bd9a320d863a9110a3f5cf4d6",
    ),
  )
  assert_eq(
    workspace.type_hash_for_definition(service.response()),
    Ok(
      "RIHS01_9fa773b46e39cc5d02db6224d8fd520bb9caeeffc2b27c96c1e59431baba9f2a",
    ),
  )
  let set_service = parse_service_with_types(
    "rcl_interfaces",
    "SetParameters",
    "Parameter[] parameters\n---\nSetParametersResult[] results",
    [
      MessageTypeReference::new("Parameter", "Parameter"),
      MessageTypeReference::new("SetParametersResult", "SetParametersResult"),
    ],
  ).unwrap()
  assert_eq(
    workspace.type_hash_for_definition(set_service.request()),
    Ok(
      "RIHS01_130d46386b7e84ea9ecf60608a4d83cbe5e5cb7c6cc5b712b7a4e3a6c254e932",
    ),
  )
  assert_eq(
    workspace.type_hash_for_definition(set_service.response()),
    Ok(
      "RIHS01_7a0e8140a0b8d98308fa81a5403a766e610af29a239caf54b7553227906fc266",
    ),
  )
  let list_service = parse_service_with_types(
    "rcl_interfaces",
    "ListParameters",
    "string[] prefixes\nuint64 depth\n---\nListParametersResult result",
    [
      MessageTypeReference::new(
        "ListParametersResult",
        "ListParametersResult",
      ),
    ],
  ).unwrap()
  assert_eq(
    workspace.type_hash_for_definition(list_service.request()),
    Ok(
      "RIHS01_a1b0b5d6b967a5b8ac5bc8563c3ea678f349e312a6a4967227c5a96bc5ce38df",
    ),
  )
  assert_eq(
    workspace.type_hash_for_definition(list_service.response()),
    Ok(
      "RIHS01_31b937b82de3612426be79f231e386259f97e8dc843e3f2845288b4bfa296bdd",
    ),
  )
  let parameter_types_service = parse_service_with_types(
    "rcl_interfaces",
    "GetParameterTypes",
    "string[] names\n---\nuint8[] types",
    [],
  ).unwrap()
  assert_eq(
    workspace.type_hash_for_definition(parameter_types_service.request()),
    Ok(
      "RIHS01_87d7ec5ef545d4daa289d500025d31fb2437bc8b8365ca367161c4dac4be33fd",
    ),
  )
  assert_eq(
    workspace.type_hash_for_definition(parameter_types_service.response()),
    Ok(
      "RIHS01_ac1335dce67c478e669434f6ac2fbff34fcd529580f272d3006785ba8b54e47f",
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
