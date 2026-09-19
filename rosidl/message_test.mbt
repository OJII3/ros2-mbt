///|
test "ROS message parser ignores comments and generates a primitive CDR codec" {
  let definition = match
    parse_message(
      "demo_msgs", "msg", "Pose", "# position\nbool valid\nchar sign\nint8 i8\nuint8 u8\nint16 i16\nuint16 u16\nint32 x\nuint32 y\nint64 timestamp\nuint64 sequence\nfloat32 weight\nfloat64 height # inline comment\nstring frame_id\n",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(definition.package_name(), "demo_msgs")
  assert_eq(definition.interface_namespace(), "msg")
  assert_eq(definition.type_name(), "Pose")
  assert_eq(definition.fields().length(), 13)
  assert_eq(definition.fields()[0].name(), "valid")
  assert_eq(definition.fields()[12].type_name(), "string")
  let generated = definition.generate_moonbit()
  assert_true(generated.length() > 500)
  assert_true(generated.contains("pub struct Pose"))
  assert_true(generated.contains("writer.write_i8(self.sign)"))
  assert_true(generated.contains("writer.write_i16_int(self.i16)"))
  assert_true(generated.contains("writer.write_u16_uint(self.u16)"))
  assert_true(generated.contains("writer.write_f64(self.height)"))
  assert_true(generated.contains("reader.read_string()"))
  assert_true(generated.contains("pub const Pose_TYPE_HASH : String = \"RIHS01_"))
}

///|
test "ROS service parser generates request and response codecs" {
  let definition = match
    parse_service(
      "example_interfaces", "AddTwoInts", "int64 a\nint64 b\n---\nint64 sum\n",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(definition.package_name(), "example_interfaces")
  assert_eq(definition.service_name(), "AddTwoInts")
  assert_eq(definition.request().type_name(), "AddTwoInts_Request")
  assert_eq(definition.request().fields().length(), 2)
  assert_eq(definition.response().type_name(), "AddTwoInts_Response")
  assert_eq(definition.response().fields().length(), 1)
  let generated = definition.generate_moonbit()
  assert_true(generated.contains("pub struct AddTwoInts_Request"))
  assert_true(generated.contains("pub struct AddTwoInts_Response"))
  assert_true(generated.contains("writer.write_i64(self.a)"))
  assert_true(generated.contains("writer.write_i64(self.sum)"))
}

///|
test "ROS service request and response hashes match RIHS01 vectors" {
  let definition = parse_service(
    "example_interfaces",
    "AddTwoInts",
    "int64 a\nint64 b\n---\nint64 sum",
  ).unwrap()
  assert_eq(
    definition.request().type_hash(),
    Ok(
      "RIHS01_000c5fd92d6b2e1a05949348f584d6d652adea1e92d691792011ac2273508302",
    ),
  )
  assert_eq(
    definition.response().type_hash(),
    Ok(
      "RIHS01_de5c030d4af33cba2749310b249737b631594703f9300495f48bffb2b44dcc2f",
    ),
  )
}

///|
test "ROS service hash includes the generated event type" {
  let definition = parse_service(
    "example_interfaces",
    "AddTwoInts",
    "int64 a\nint64 b\n---\nint64 sum",
  ).unwrap()
  assert_eq(
    definition.type_hash(),
    Ok(
      "RIHS01_de8fec42de89bb46c66d22e7108914c4334d3555d679de8ff3ab5f4d7fe95c42",
    ),
  )
}

///|
test "ROS service parser requires exactly one separator" {
  assert_true(parse_service("demo", "Empty", "int32 value") is Err(_))
  assert_true(
    parse_service("demo", "Empty", "int32 value\n---\n---\n") is Err(_),
  )
}

///|
test "ROS message parser and generator handle scalar constants" {
  let definition = match
    parse_message(
      "demo", "msg", "Limits", "int32 MAX=42\nfloat64 SCALE=1.5\nstring LABEL=\"demo\"\nint32 value",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(definition.constants().length(), 3)
  assert_eq(definition.constants()[0].name(), "MAX")
  assert_eq(definition.constants()[2].value(), "\"demo\"")
  let generated = definition.generate_moonbit()
  assert_true(generated.contains("pub const MAX : Int = 42"))
  assert_true(generated.contains("pub const SCALE : Double = 1.5"))
  assert_true(generated.contains("pub const LABEL : String = \"demo\""))
}

///|
test "ROS message generator handles fixed arrays and sequences" {
  let definition = match
    parse_message("demo", "msg", "Arrays", "int32[3] values\nfloat64[] samples") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(
    definition.fields()[0].collection(),
    MessageFieldCollection::FixedArray(3),
  )
  assert_eq(
    definition.fields()[1].collection(),
    MessageFieldCollection::Sequence,
  )
  let generated = definition.generate_moonbit()
  assert_true(generated.contains("for _ in 0..<3"))
  assert_true(generated.contains("writer.write_u32(self.samples.length()"))
  assert_true(generated.contains("samples_length"))
}

///|
test "ROS message generator handles bounded sequences" {
  let definition = match
    parse_message("demo", "msg", "Bounded", "int32[<=3] values") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(
    definition.fields()[0].collection(),
    MessageFieldCollection::BoundedSequence(3),
  )
  let generated = definition.generate_moonbit()
  assert_true(generated.contains("writer.write_u32(self.values.length()"))
  assert_true(generated.contains("values_length > 3"))
}

///|
test "ROS message generator handles nested message fields" {
  let nested_types : Array[MessageTypeReference] = [
    MessageTypeReference::new("geometry_msgs/msg/Vector3", "Vector3"),
  ]
  let definition = match
    parse_message_with_types(
      "demo", "msg", "Pose", "geometry_msgs/msg/Vector3 position\ngeometry_msgs/msg/Vector3[] history\ngeometry_msgs/msg/Vector3[<=2] bounded",
      nested_types,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(definition.nested_types().length(), 1)
  assert_eq(definition.fields()[0].type_name(), "geometry_msgs/msg/Vector3")
  let generated = definition.generate_moonbit()
  assert_true(generated.contains("position : Vector3"))
  assert_true(generated.contains("self.position.write_cdr(writer)"))
  assert_true(generated.contains("Vector3::read_cdr(reader)"))
  assert_true(generated.contains("bounded_length > 2"))
}

///|
test "ROS message workspace resolves local dependencies in dependency order" {
  let vector = match
    MessageSource::new(
      "demo_msgs", "msg", "Vector3", "float64 x\nfloat64 y\nfloat64 z\n",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let pose = match
    MessageSource::new(
      "demo_msgs", "msg", "Pose", "Vector3 position\nVector3[] history\n",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let workspace = MessageWorkspace::new()
  match workspace.add_source(pose) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match workspace.add_source(vector) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let ordered = match workspace.dependency_order("demo_msgs", "msg") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(ordered.length(), 2)
  assert_eq(ordered[0].type_name(), "Vector3")
  assert_eq(ordered[1].type_name(), "Pose")
  let generated = match workspace.generate_moonbit("demo_msgs", "msg") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_true(generated.contains("pub struct Vector3"))
  assert_true(generated.contains("pub struct Pose"))
  assert_true(generated.contains("position : Vector3"))
  assert_true(generated.contains("Vector3::read_cdr(reader)"))
}

///|
test "ROS message workspace generates qualified external imports" {
  let mapping = match
    MessageImport::new("geometry_msgs", "vendor/geometry_msgs/msg", "geometry") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let pose = match
    MessageSource::new(
      "demo_msgs", "msg", "Pose", "geometry_msgs/Vector3 position\n",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let workspace = MessageWorkspace::new()
  match workspace.add_import(mapping) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match workspace.add_source(pose) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let generated = match
    workspace.generate_message_moonbit("demo_msgs", "msg", "Pose") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_true(generated.contains("\"vendor/geometry_msgs/msg\" @geometry"))
  assert_true(generated.contains("position : @geometry.Vector3"))
  assert_true(generated.contains("@geometry.Vector3::read_cdr(reader)"))
}

///|
test "ROS message workspace rejects missing imports and cycles" {
  let missing = match
    MessageSource::new(
      "demo_msgs", "msg", "Pose", "geometry_msgs/Vector3 position\n",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let missing_workspace = MessageWorkspace::new()
  match missing_workspace.add_source(missing) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  assert_true(
    missing_workspace.generate_message_moonbit("demo_msgs", "msg", "Pose")
    is Err(_),
  )

  let first = match
    MessageSource::new("demo_msgs", "msg", "First", "Second value\n") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let second = match
    MessageSource::new("demo_msgs", "msg", "Second", "First value\n") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let cyclic_workspace = MessageWorkspace::new()
  match cyclic_workspace.add_source(first) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match cyclic_workspace.add_source(second) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  assert_true(cyclic_workspace.dependency_order("demo_msgs", "msg") is Err(_))
}

///|
test "ROS message parser rejects unsupported definitions" {
  assert_true(parse_message("demo", "msg", "Bad", "int32[<3] values") is Err(_))
  assert_true(
    parse_message("demo", "msg", "Bad", "int32[<=0] values") is Err(_),
  )
  assert_true(parse_message("demo", "msg", "Bad", "other_type value") is Err(_))
  assert_true(
    parse_message("demo", "msg", "Bad", "int32 VALUE-NOT-ID") is Err(_),
  )
  assert_true(
    parse_message("demo", "msg", "Bad", "int32 BAD=not_number") is Err(_),
  )
  let nested_types : Array[MessageTypeReference] = [
    MessageTypeReference::new("Vector3", "Vector3"),
  ]
  assert_true(
    parse_message_with_types(
      "demo", "msg", "Bad", "Missing value", nested_types,
    )
    is Err(_),
  )
}
