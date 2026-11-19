///|
test "CDR numeric arrays round trip" {
  let writer = @cdr.Writer::new()
  writer.write_u8(7)
  writer.write_f64_array([1.5, -2.25, 3.0])
  writer.write_f32_array([0.5F, -1.25F])
  writer.write_i32_array([-1, 2, -3])
  writer.write_u32_array([4U, 5U, 6U])
  writer.write_f64_sequence([7.5, 8.5])
  writer.write_f32_sequence([9.5F])
  writer.write_i32_sequence([10, 11])
  writer.write_u32_sequence([12U, 13U])
  let reader = @cdr.Reader::from_bytes(writer.to_bytes()).unwrap()
  assert_eq(reader.read_u8().unwrap(), 7)
  assert_eq(reader.read_f64_array(3).unwrap(), [1.5, -2.25, 3.0])
  assert_eq(reader.read_f32_array(2).unwrap(), [0.5F, -1.25F])
  assert_eq(reader.read_i32_array(3).unwrap(), [-1, 2, -3])
  assert_eq(reader.read_u32_array(3).unwrap(), [4U, 5U, 6U])
  assert_eq(reader.read_f64_sequence().unwrap(), [7.5, 8.5])
  assert_eq(reader.read_f32_sequence().unwrap(), [9.5F])
  assert_eq(reader.read_i32_sequence().unwrap(), [10, 11])
  assert_eq(reader.read_u32_sequence().unwrap(), [12U, 13U])
  assert_eq(reader.remaining(), 0)
}

///|
test "CDR numeric arrays reject truncated or negative lengths" {
  let writer = @cdr.Writer::new()
  writer.write_f64_array([1.0, 2.0])
  let reader = @cdr.Reader::from_bytes(writer.to_bytes()).unwrap()
  assert_true(reader.read_f64_array(3) is Err(_))

  let negative = @cdr.Reader::from_bytes(writer.to_bytes()).unwrap()
  assert_true(negative.read_f64_array(-1) is Err(_))

  let writer = @cdr.Writer::new()
  writer.write_u32(3U)
  writer.write_f64_array([1.0, 2.0])
  let truncated = @cdr.Reader::from_bytes(writer.to_bytes()).unwrap()
  assert_true(truncated.read_f64_sequence() is Err(_))
}
