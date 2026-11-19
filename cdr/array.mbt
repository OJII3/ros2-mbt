///|
/// Read a CDR fixed-size `float64` array without a length prefix.
pub fn Reader::read_f64_array(
  self : Reader,
  length : Int32,
) -> Result[Array[Double], String] {
  if length < 0 {
    return Err("truncated CDR payload")
  }
  let start = self.aligned_offset(8)
  if length > (self.bytes.length() - start) / 8 {
    return Err("truncated CDR payload")
  }
  self.offset = start + length * 8
  let values = Array::make(length, 0.0)
  for index in 0..<length {
    values[index] = cdr_reader_read_u64(
      self.bytes,
      start + index * 8,
      self.little_endian,
    ).reinterpret_as_double()
  }
  Ok(values)
}

///|
/// Read a CDR `float64` sequence with a uint32 length prefix.
pub fn Reader::read_f64_sequence(
  self : Reader,
) -> Result[Array[Double], String] {
  let start = self.aligned_offset(4)
  if start > self.bytes.length() - 4 {
    return Err("truncated CDR payload")
  }
  self.offset = start + 4
  let length = cdr_reader_read_u32(self.bytes, start, self.little_endian).reinterpret_as_int()
  self.read_f64_array(length)
}

///|
/// Read a CDR fixed-size `float32` array without a length prefix.
pub fn Reader::read_f32_array(
  self : Reader,
  length : Int32,
) -> Result[Array[Float], String] {
  if length < 0 {
    return Err("truncated CDR payload")
  }
  let start = self.aligned_offset(4)
  if length > (self.bytes.length() - start) / 4 {
    return Err("truncated CDR payload")
  }
  self.offset = start + length * 4
  let values = Array::make(length, 0.0F)
  for index in 0..<length {
    values[index] = Float::reinterpret_from_uint(
      cdr_reader_read_u32(self.bytes, start + index * 4, self.little_endian),
    )
  }
  Ok(values)
}

///|
/// Read a CDR `float32` sequence with a uint32 length prefix.
pub fn Reader::read_f32_sequence(self : Reader) -> Result[Array[Float], String] {
  let start = self.aligned_offset(4)
  if start > self.bytes.length() - 4 {
    return Err("truncated CDR payload")
  }
  self.offset = start + 4
  let length = cdr_reader_read_u32(self.bytes, start, self.little_endian).reinterpret_as_int()
  self.read_f32_array(length)
}

///|
/// Read a CDR fixed-size signed 32-bit array without a length prefix.
pub fn Reader::read_i32_array(
  self : Reader,
  length : Int32,
) -> Result[Array[Int32], String] {
  if length < 0 {
    return Err("truncated CDR payload")
  }
  let start = self.aligned_offset(4)
  if length > (self.bytes.length() - start) / 4 {
    return Err("truncated CDR payload")
  }
  self.offset = start + length * 4
  let values = Array::make(length, 0)
  for index in 0..<length {
    values[index] = cdr_reader_read_u32(
      self.bytes,
      start + index * 4,
      self.little_endian,
    ).reinterpret_as_int()
  }
  Ok(values)
}

///|
/// Read a CDR signed 32-bit sequence with a uint32 length prefix.
pub fn Reader::read_i32_sequence(self : Reader) -> Result[Array[Int32], String] {
  let start = self.aligned_offset(4)
  if start > self.bytes.length() - 4 {
    return Err("truncated CDR payload")
  }
  self.offset = start + 4
  let length = cdr_reader_read_u32(self.bytes, start, self.little_endian).reinterpret_as_int()
  self.read_i32_array(length)
}

///|
/// Read a CDR fixed-size unsigned 32-bit array without a length prefix.
pub fn Reader::read_u32_array(
  self : Reader,
  length : Int32,
) -> Result[Array[UInt32], String] {
  if length < 0 {
    return Err("truncated CDR payload")
  }
  let start = self.aligned_offset(4)
  if length > (self.bytes.length() - start) / 4 {
    return Err("truncated CDR payload")
  }
  self.offset = start + length * 4
  let values = Array::make(length, 0U)
  for index in 0..<length {
    values[index] = cdr_reader_read_u32(
      self.bytes,
      start + index * 4,
      self.little_endian,
    )
  }
  Ok(values)
}

///|
/// Read a CDR unsigned 32-bit sequence with a uint32 length prefix.
pub fn Reader::read_u32_sequence(
  self : Reader,
) -> Result[Array[UInt32], String] {
  let start = self.aligned_offset(4)
  if start > self.bytes.length() - 4 {
    return Err("truncated CDR payload")
  }
  self.offset = start + 4
  let length = cdr_reader_read_u32(self.bytes, start, self.little_endian).reinterpret_as_int()
  self.read_u32_array(length)
}

///|
/// Write a CDR fixed-size `float64` array without a length prefix.
pub fn Writer::write_f64_array(
  self : Writer,
  values : ArrayView[Double],
) -> Unit {
  self.align(8)
  for value in values {
    self.buffer.write_double_le(value)
  }
}

///|
/// Write a CDR `float64` sequence with a uint32 length prefix.
pub fn Writer::write_f64_sequence(
  self : Writer,
  values : ArrayView[Double],
) -> Unit {
  self.write_u32(values.length().reinterpret_as_uint())
  self.write_f64_array(values)
}

///|
/// Write a CDR fixed-size `float32` array without a length prefix.
pub fn Writer::write_f32_array(
  self : Writer,
  values : ArrayView[Float],
) -> Unit {
  self.align(4)
  for value in values {
    self.buffer.write_float_le(value)
  }
}

///|
/// Write a CDR `float32` sequence with a uint32 length prefix.
pub fn Writer::write_f32_sequence(
  self : Writer,
  values : ArrayView[Float],
) -> Unit {
  self.write_u32(values.length().reinterpret_as_uint())
  self.write_f32_array(values)
}

///|
/// Write a CDR fixed-size signed 32-bit array without a length prefix.
pub fn Writer::write_i32_array(
  self : Writer,
  values : ArrayView[Int32],
) -> Unit {
  self.align(4)
  for value in values {
    self.buffer.write_int_le(value)
  }
}

///|
/// Write a CDR signed 32-bit sequence with a uint32 length prefix.
pub fn Writer::write_i32_sequence(
  self : Writer,
  values : ArrayView[Int32],
) -> Unit {
  self.write_u32(values.length().reinterpret_as_uint())
  self.write_i32_array(values)
}

///|
/// Write a CDR fixed-size unsigned 32-bit array without a length prefix.
pub fn Writer::write_u32_array(
  self : Writer,
  values : ArrayView[UInt32],
) -> Unit {
  self.align(4)
  for value in values {
    self.buffer.write_uint_le(value)
  }
}

///|
/// Write a CDR unsigned 32-bit sequence with a uint32 length prefix.
pub fn Writer::write_u32_sequence(
  self : Writer,
  values : ArrayView[UInt32],
) -> Unit {
  self.write_u32(values.length().reinterpret_as_uint())
  self.write_u32_array(values)
}
