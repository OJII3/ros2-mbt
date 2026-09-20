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
  // The encapsulation header is not part of the CDR stream used for
  // alignment. XCDR1 therefore aligns from the first byte after the header.
  let remainder = (self.buffer.length() - ENCAPSULATION_LENGTH) % alignment
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
/// Write a CDR boolean encoded as 0 or 1.
pub fn Writer::write_bool(self : Writer, value : Bool) -> Unit {
  self.write_u8(if value { 1 } else { 0 })
}

///|
/// Write a CDR octet without alignment.
pub fn Writer::write_u8(self : Writer, value : Byte) -> Unit {
  self.buffer.write_byte(value)
}

///|
/// Write a signed CDR int8 without alignment.
pub fn Writer::write_i8(self : Writer, value : Int) -> Unit {
  self.buffer.write_byte(value.reinterpret_as_uint().to_byte())
}

///|
/// Write a signed 16-bit integer with CDR alignment.
pub fn Writer::write_i16(self : Writer, value : Int16) -> Unit {
  self.align(2)
  self.buffer.write_int16_le(value)
}

///|
/// Write a signed CDR int16 from a MoonBit Int.
pub fn Writer::write_i16_int(self : Writer, value : Int) -> Unit {
  self.align(2)
  let encoded = value.reinterpret_as_uint()
  self.buffer.write_byte(encoded.to_byte())
  self.buffer.write_byte((encoded >> 8).to_byte())
}

///|
/// Write an unsigned 16-bit integer with CDR alignment.
pub fn Writer::write_u16(self : Writer, value : UInt16) -> Unit {
  self.align(2)
  self.buffer.write_uint16_le(value)
}

///|
/// Write a CDR uint16 from a MoonBit UInt.
pub fn Writer::write_u16_uint(self : Writer, value : UInt) -> Unit {
  self.align(2)
  self.buffer.write_byte(value.to_byte())
  self.buffer.write_byte((value >> 8).to_byte())
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

///|
/// Write a UTF-8 CDR string if it fits within a character-count bound.
pub fn Writer::write_bounded_string(
  self : Writer,
  value : String,
  maximum_length : Int,
) -> Result[Unit, String] {
  if maximum_length < 0 {
    return Err("a CDR string bound must not be negative")
  }
  if cdr_utf8_character_count(value) > maximum_length {
    return Err("CDR string exceeds its character bound")
  }
  self.write_string(value)
  Ok(())
}

///|
/// Write a ROS wide string as UTF-16 code units widened to CDR wchar.
pub fn Writer::write_wstring(
  self : Writer,
  value : String,
) -> Result[Unit, String] {
  let units = match cdr_utf16_code_units(value) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  self.write_u32(units.length().reinterpret_as_uint())
  for unit in units {
    self.write_u32(unit)
  }
  Ok(())
}

///|
/// Write a ROS wide string if it fits within its UTF-16 code-unit bound.
pub fn Writer::write_bounded_wstring(
  self : Writer,
  value : String,
  maximum_length : Int,
) -> Result[Unit, String] {
  if maximum_length < 0 {
    return Err("a CDR wide-string bound must not be negative")
  }
  let units = match cdr_utf16_code_units(value) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if units.length() > maximum_length {
    return Err("CDR wide string exceeds its code-unit bound")
  }
  self.write_u32(units.length().reinterpret_as_uint())
  for unit in units {
    self.write_u32(unit)
  }
  Ok(())
}

///|
fn cdr_utf16_code_units(value : String) -> Result[Array[UInt], String] {
  let bytes = @utf8.encode(value)
  let units : Array[UInt] = []
  let mut index = 0
  while index < bytes.length() {
    let first = bytes[index].to_int()
    let (codepoint, width) = if first <= 0x7F {
      (first, 1)
    } else if first >= 0xC2 && first <= 0xDF && index + 1 < bytes.length() {
      let second = bytes[index + 1].to_int()
      if second < 0x80 || second > 0xBF {
        return Err("invalid UTF-8 in CDR wide string")
      }
      (((first & 0x1F) << 6) | (second & 0x3F), 2)
    } else if first >= 0xE0 && first <= 0xEF && index + 2 < bytes.length() {
      let second = bytes[index + 1].to_int()
      let third = bytes[index + 2].to_int()
      if second < 0x80 || second > 0xBF || third < 0x80 || third > 0xBF ||
        (first == 0xE0 && second < 0xA0) ||
        (first == 0xED && second >= 0xA0) {
        return Err("invalid UTF-8 in CDR wide string")
      }
      (
        ((first & 0x0F) << 12) | ((second & 0x3F) << 6) | (third & 0x3F),
        3,
      )
    } else if first >= 0xF0 && first <= 0xF4 && index + 3 < bytes.length() {
      let second = bytes[index + 1].to_int()
      let third = bytes[index + 2].to_int()
      let fourth = bytes[index + 3].to_int()
      if second < 0x80 || second > 0xBF || third < 0x80 || third > 0xBF ||
        fourth < 0x80 || fourth > 0xBF ||
        (first == 0xF0 && second < 0x90) ||
        (first == 0xF4 && second > 0x8F) {
        return Err("invalid UTF-8 in CDR wide string")
      }
      (
        ((first & 0x07) << 18) | ((second & 0x3F) << 12) |
        ((third & 0x3F) << 6) | (fourth & 0x3F),
        4,
      )
    } else {
      return Err("invalid UTF-8 in CDR wide string")
    }
    if codepoint == 0 {
      return Err("CDR wide strings must not contain NUL")
    }
    if codepoint <= 0xFFFF {
      units.push(codepoint.reinterpret_as_uint())
    } else {
      let supplementary = codepoint - 0x10000
      units.push((0xD800 + (supplementary >> 10)).reinterpret_as_uint())
      units.push((0xDC00 + (supplementary & 0x3FF)).reinterpret_as_uint())
    }
    index += width
  }
  Ok(units)
}

///|
fn cdr_utf8_character_count(value : String) -> Int {
  let encoded = @utf8.encode(value)
  let mut count = 0
  for byte in encoded {
    if byte < 0x80 || byte > 0xBF {
      count += 1
    }
  }
  count
}
