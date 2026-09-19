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
}
