///|
fn parameter_test_append_u16_be(bytes : Array[Byte], value : UInt) -> Unit {
  bytes.push((value >> 8).to_byte())
  bytes.push(value.to_byte())
}

///|
fn parameter_test_append_u32_be(bytes : Array[Byte], value : UInt) -> Unit {
  bytes.push((value >> 24).to_byte())
  bytes.push((value >> 16).to_byte())
  bytes.push((value >> 8).to_byte())
  bytes.push(value.to_byte())
}

///|
fn parameter_test_append_be_parameter(
  bytes : Array[Byte],
  id : UInt16,
  value : Bytes,
) -> Unit {
  let length = (value.length() + 3) / 4 * 4
  parameter_test_append_u16_be(bytes, id.to_int().reinterpret_as_uint())
  parameter_test_append_u16_be(bytes, length.reinterpret_as_uint())
  for byte in value {
    bytes.push(byte)
  }
  for _ in 0..<(length - value.length()) {
    bytes.push(0)
  }
}

///|
fn parameter_test_be_u32(value : UInt) -> Bytes {
  let bytes : Array[Byte] = []
  parameter_test_append_u32_be(bytes, value)
  Bytes::from_array(bytes)
}
