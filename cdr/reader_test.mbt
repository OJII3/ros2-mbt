///|
test "CDR reader round trips primitive values" {
  let writer = Writer::new()
  writer.write_bool(true)
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
  assert_eq(reader.read_bool(), Ok(true))
  assert_eq(reader.read_u8(), Ok(0x7F))
  assert_eq(reader.read_i16(), Ok(-1234))
  assert_eq(reader.read_u32(), Ok(0x01020304U))
  assert_eq(reader.read_i64(), Ok(-123456789L))
  assert_eq(reader.read_f32(), Ok(1.5F))
  assert_eq(reader.read_f64(), Ok(-2.5))
  assert_eq(reader.remaining(), 0)
}

///|
test "CDR reader decodes big-endian primitive values" {
  let reader = Reader::from_bytes(
    b"\x00\x00\x00\x00\x01\xFE\xFB\x2E\xD4\x31\x00\x00\xF8\xA4\x32\xEB\x01\x02\x03\x04\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x01\x02\x03\x04\x05\x06\x07\x08\x3F\xC0\x00\x00\x00\x00\x00\x00\xC0\x04\x00\x00\x00\x00\x00\x00",
  ).unwrap()
  assert_eq(reader.read_bool(), Ok(true))
  assert_eq(reader.read_i8(), Ok(-2))
  assert_eq(reader.read_i16(), Ok(-1234))
  assert_eq(reader.read_u16(), Ok(54321U))
  assert_eq(reader.read_i32(), Ok(-123456789))
  assert_eq(reader.read_u32(), Ok(0x01020304U))
  assert_eq(reader.read_i64(), Ok(-1L))
  assert_eq(reader.read_u64(), Ok(0x0102030405060708UL))
  assert_eq(reader.read_f32(), Ok(1.5F))
  assert_eq(reader.read_f64(), Ok(-2.5))
  assert_eq(reader.remaining(), 0)
}

///|
test "CDR reader decodes big-endian strings and byte sequences" {
  let reader = Reader::from_bytes(
    b"\x00\x00\x00\x00\x00\x00\x00\x02x\x00\x00\x00\x00\x00\x00\x03\x01\x02\x03",
  ).unwrap()
  assert_eq(reader.read_string(), Ok("x"))
  assert_eq(reader.read_byte_sequence(), Ok(b"\x01\x02\x03"))
  assert_eq(reader.remaining(), 0)
}

///|
test "CDR signed 8-bit and MoonBit-sized 16-bit helpers" {
  let writer = Writer::new()
  writer.write_i8(-2)
  writer.write_i16_int(-1234)
  writer.write_u16_uint(54321U)
  let reader = match Reader::from_bytes(writer.to_bytes()) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(reader.read_i8(), Ok(-2))
  assert_eq(reader.read_i16(), Ok(-1234))
  assert_eq(reader.read_u16(), Ok(54321U))
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
test "CDR reader decodes widened UTF-16 wide strings" {
  let reader = Reader::from_bytes(
    b"\x00\x01\x00\x00\x04\x00\x00\x00\x41\x00\x00\x00\x2B\x73\x00\x00\x3D\xD8\x00\x00\x42\xDE\x00\x00",
  ).unwrap()
  assert_eq(reader.read_wstring(), Ok("A猫🙂"))
  assert_eq(reader.remaining(), 0)
}

///|
test "CDR reader enforces bounded wide-string code-unit counts" {
  let writer = Writer::new()
  writer.write_wstring("🙂").unwrap()
  let reader = Reader::from_bytes(writer.to_bytes()).unwrap()
  assert_true(reader.read_bounded_wstring(1) is Err(_))

  let reader = Reader::from_bytes(writer.to_bytes()).unwrap()
  assert_eq(reader.read_bounded_wstring(2), Ok("🙂"))
  assert_eq(reader.remaining(), 0)
}

///|
test "CDR reader rejects malformed widened UTF-16 wide strings" {
  let high_surrogate = Reader::from_bytes(
    b"\x00\x01\x00\x00\x01\x00\x00\x00\x00\xD8\x00\x00",
  ).unwrap()
  assert_true(high_surrogate.read_wstring() is Err(_))

  let nul_character = Reader::from_bytes(
    b"\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00",
  ).unwrap()
  assert_true(nul_character.read_wstring() is Err(_))
}

///|
test "CDR reader enforces bounded string character counts" {
  let writer = Writer::new()
  writer.write_string("猫犬")
  let reader = Reader::from_bytes(writer.to_bytes()).unwrap()
  assert_true(reader.read_bounded_string(1) is Err(_))

  let reader = Reader::from_bytes(writer.to_bytes()).unwrap()
  assert_eq(reader.read_bounded_string(2), Ok("猫犬"))
  assert_eq(reader.remaining(), 0)
}

///|
test "CDR reader accepts little-endian encapsulation options" {
  let reader = match Reader::from_bytes(
    b"\x00\x01\x00\x01\x02\x00\x00\x00x\x00",
  ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(reader.read_string(), Ok("x"))
  assert_eq(reader.remaining(), 0)
}

///|
test "CDR reader rejects malformed payloads" {
  assert_true(Reader::from_bytes(b"bad") is Err(_))
  assert_true(Reader::from_bytes(b"\x00\x02\x00\x00") is Err(_))
  let reader = match Reader::from_bytes(b"\x00\x01\x00\x00\x01") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_true(reader.read_u32() is Err(_))
  let padded = match Reader::from_bytes(b"\x00\x01\x00\x00\x00") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_true(padded.remaining_is_zero_padding(4))
  let nonzero = match Reader::from_bytes(b"\x00\x01\x00\x00\x01") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_false(nonzero.remaining_is_zero_padding(4))
}

///|
test "CDR reader rejects overflowing sequence and string lengths" {
  let malformed_payload = Bytes::from_array([
    0, 1, 0, 0, 0xFC, 0xFF, 0xFF, 0x7F,
  ])
  let sequence_reader = Reader::from_bytes(malformed_payload).unwrap()
  assert_true(sequence_reader.read_byte_sequence() is Err(_))

  let string_reader = Reader::from_bytes(malformed_payload).unwrap()
  assert_true(string_reader.read_string() is Err(_))
}
