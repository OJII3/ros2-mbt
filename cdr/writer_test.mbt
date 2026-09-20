///|
test "CDR writer writes encapsulation and aligned integers" {
  let writer = Writer::new()
  writer.write_u8(0x7F)
  writer.write_u32(0x01020304U)
  assert_eq(
    writer.to_bytes(),
    b"\x00\x01\x00\x00\x7F\x00\x00\x00\x04\x03\x02\x01",
  )
}

///|
test "CDR writer writes floating point values" {
  let writer = Writer::new()
  writer.write_f32(1.0F)
  writer.write_f64(1.0)
  assert_eq(
    writer.to_bytes(),
    b"\x00\x01\x00\x00\x00\x00\x80\x3F\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xF0\x3F",
  )
}

///|
test "CDR aligns aggregate fields after the encapsulation header" {
  let writer = Writer::new()
  writer.write_i64(2L)
  writer.write_i64(3L)
  assert_eq(
    writer.to_bytes(),
    b"\x00\x01\x00\x00\x02\x00\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00\x00\x00\x00\x00",
  )
}

///|
test "CDR writer writes strings and byte sequences" {
  let writer = Writer::new()
  writer.write_string("hi")
  writer.write_byte_sequence(b"\x01\x02\x03")
  assert_eq(
    writer.to_bytes(),
    b"\x00\x01\x00\x00\x03\x00\x00\x00hi\x00\x00\x03\x00\x00\x00\x01\x02\x03",
  )
}

///|
test "CDR writer accepts non-ASCII UTF-8 strings" {
  let writer = Writer::new()
  writer.write_string("こんにちは")
  assert_eq(
    writer.to_bytes(),
    b"\x00\x01\x00\x00\x10\x00\x00\x00こんにちは\x00",
  )
}

///|
test "CDR writer encodes wide strings as UTF-16 code units" {
  let writer = Writer::new()
  assert_eq(writer.write_wstring("A猫🙂"), Ok(()))
  assert_eq(
    writer.to_bytes(),
    b"\x00\x01\x00\x00\x04\x00\x00\x00\x41\x00\x2B\x73\x3D\xD8\x42\xDE",
  )
}

///|
test "CDR writer enforces bounded wide-string code-unit counts" {
  let writer = Writer::new()
  assert_eq(writer.write_bounded_wstring("🙂", 2), Ok(()))
  let before = writer.to_bytes()
  assert_true(writer.write_bounded_wstring("🙂", 1) is Err(_))
  assert_eq(writer.to_bytes(), before)
  assert_true(writer.write_wstring("\u0000") is Err(_))
}

///|
test "CDR writer enforces bounded string character counts" {
  let writer = Writer::new()
  assert_eq(writer.write_bounded_string("猫", 1), Ok(()))
  let before = writer.to_bytes()
  assert_true(writer.write_bounded_string("猫犬", 1) is Err(_))
  assert_eq(writer.to_bytes(), before)
}
