///|
test "ROS message parser ignores comments and generates a scalar CDR codec" {
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
test "ROS message parser rejects unsupported definitions" {
  assert_true(parse_message("demo", "msg", "Bad", "int32[3] values") is Err(_))
  assert_true(parse_message("demo", "msg", "Bad", "other_type value") is Err(_))
  assert_true(
    parse_message("demo", "msg", "Bad", "int32 VALUE-NOT-ID") is Err(_),
  )
  assert_true(parse_message("demo", "msg", "Bad", "int32 answer=42") is Err(_))
}
