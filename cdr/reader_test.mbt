///|
test "CDR reader round trips primitive values" {
  let writer = Writer::new()
  writer.write_u8(0x7F)
  writer.write_i16(-1234)
  writer.write_u32(0x01020304U)
  writer.write_i64(-123456789L)
  writer.write_f32(1.5F)
  writer.write_f64(-2.5)
  let reader = match Reader::from_bytes(writer.to_bytes()) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(reader.read_u8(), Ok(0x7F))
  assert_eq(reader.read_i16(), Ok(-1234))
  assert_eq(reader.read_u32(), Ok(0x01020304U))
  assert_eq(reader.read_i64(), Ok(-123456789L))
  assert_eq(reader.read_f32(), Ok(1.5F))
  assert_eq(reader.read_f64(), Ok(-2.5))
  assert_eq(reader.remaining(), 0)
}

///|
test "CDR reader round trips strings and sequences" {
  let writer = Writer::new()
  writer.write_string("こんにちは")
  writer.write_byte_sequence(b"\x01\x02\x03")
  let reader = match Reader::from_bytes(writer.to_bytes()) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(reader.read_string(), Ok("こんにちは"))
  assert_eq(reader.read_byte_sequence(), Ok(b"\x01\x02\x03"))
  assert_eq(reader.remaining(), 0)
}

///|
test "CDR reader rejects malformed payloads" {
  assert_true(Reader::from_bytes(b"bad") is Err(_))
  assert_true(Reader::from_bytes(b"\x00\x00\x00\x00") is Err(_))
  let reader = match Reader::from_bytes(b"\x00\x01\x00\x00\x01") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_true(reader.read_u32() is Err(_))
}
