///|
/// CDR little-endian encapsulation identifier used by ROS 2.
pub const CDR_LE : UInt16 = 0x0001

///|
/// The four-byte CDR encapsulation header.
pub const ENCAPSULATION_LENGTH : Int = 4

///| A CDR little-endian writer.

///|
/// The writer starts with a CDR encapsulation header, so `to_bytes()` returns
/// a complete ROS 2 serialized payload rather than only the serialized body.
pub struct Writer {
  buffer : @buffer.Buffer
}

///|
/// Create an empty CDR little-endian payload.
pub fn Writer::new() -> Writer {
  let buffer = @buffer.Buffer()
  // The encapsulation header itself is written in network byte order. The
  // CDR body that follows is little-endian.
  buffer.write_byte(0)
  buffer.write_byte(1)
  buffer.write_byte(0)
  buffer.write_byte(0)
  { buffer, }
}

///|
/// Create a writer with a buffer capacity hint.
pub fn Writer::with_capacity(size_hint : Int) -> Writer {
  let buffer = @buffer.Buffer(size_hint~)
  buffer.write_byte(0)
  buffer.write_byte(1)
  buffer.write_byte(0)
  buffer.write_byte(0)
  { buffer, }
}

///|
fn Writer::align(self : Writer, alignment : Int) -> Unit {
  let remainder = self.buffer.length() % alignment
  if remainder != 0 {
    let padding = alignment - remainder
    for _ in 0..<padding {
      self.buffer.write_byte(0)
    }
  }
}

///|
/// Return the complete serialized CDR payload.
pub fn Writer::to_bytes(self : Writer) -> Bytes {
  self.buffer.to_bytes()
}

///|
/// Return the current serialized length in bytes.
pub fn Writer::length(self : Writer) -> Int {
  self.buffer.length()
}

///|
/// Write a CDR octet without alignment.
pub fn Writer::write_u8(self : Writer, value : Byte) -> Unit {
  self.buffer.write_byte(value)
}

///|
/// Write a signed 16-bit integer with CDR alignment.
pub fn Writer::write_i16(self : Writer, value : Int16) -> Unit {
  self.align(2)
  self.buffer.write_int16_le(value)
}

///|
/// Write an unsigned 16-bit integer with CDR alignment.
pub fn Writer::write_u16(self : Writer, value : UInt16) -> Unit {
  self.align(2)
  self.buffer.write_uint16_le(value)
}

///|
/// Write a signed 32-bit integer with CDR alignment.
pub fn Writer::write_i32(self : Writer, value : Int) -> Unit {
  self.align(4)
  self.buffer.write_int_le(value)
}

///|
/// Write an unsigned 32-bit integer with CDR alignment.
pub fn Writer::write_u32(self : Writer, value : UInt) -> Unit {
  self.align(4)
  self.buffer.write_uint_le(value)
}

///|
/// Write a signed 64-bit integer with CDR alignment.
pub fn Writer::write_i64(self : Writer, value : Int64) -> Unit {
  self.align(8)
  self.buffer.write_int64_le(value)
}

///|
/// Write an unsigned 64-bit integer with CDR alignment.
pub fn Writer::write_u64(self : Writer, value : UInt64) -> Unit {
  self.align(8)
  self.buffer.write_uint64_le(value)
}

///|
/// Write an IEEE-754 single-precision value with CDR alignment.
pub fn Writer::write_f32(self : Writer, value : Float) -> Unit {
  self.align(4)
  self.buffer.write_float_le(value)
}

///|
/// Write an IEEE-754 double-precision value with CDR alignment.
pub fn Writer::write_f64(self : Writer, value : Double) -> Unit {
  self.align(8)
  self.buffer.write_double_le(value)
}

///|
/// Write a raw, fixed-size byte array without a sequence length.
pub fn Writer::write_byte_array(self : Writer, value : Bytes) -> Unit {
  self.buffer.write_bytes(value[:])
}

///|
/// Write a byte sequence as a CDR sequence (length followed by bytes).
pub fn Writer::write_byte_sequence(self : Writer, value : Bytes) -> Unit {
  self.write_u32(value.length().reinterpret_as_uint())
  self.write_byte_array(value)
}

///|
/// Write a UTF-8 CDR string, including its terminating NUL byte.
pub fn Writer::write_string(self : Writer, value : String) -> Unit {
  let encoded = @utf8.encode(value)
  self.write_u32((encoded.length() + 1).reinterpret_as_uint())
  self.write_byte_array(encoded)
  self.write_u8(0)
}
