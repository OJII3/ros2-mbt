///|
/// CDR big-endian encapsulation identifier.
pub const CDR_BE : UInt16 = 0x0000

///|
/// A cursor for reading a ROS 2 CDR payload.
pub struct Reader {
  bytes : Bytes
  mut offset : Int
  little_endian : Bool
}

///|
/// Start reading a CDR big-endian or little-endian payload.
pub fn Reader::from_bytes(bytes : Bytes) -> Result[Reader, String] {
  if bytes.length() < ENCAPSULATION_LENGTH {
    return Err("a CDR payload must contain a 4-byte encapsulation header")
  }
  // The final two bytes are encapsulation options. Cyclone DDS sets one of
  // these option bits for otherwise ordinary little-endian CDR payloads.
  if bytes[0] != 0 || (bytes[1] != 0 && bytes[1] != 1) {
    return Err("only CDR_BE and CDR_LE encapsulations are supported")
  }
  Ok({ bytes, offset: ENCAPSULATION_LENGTH, little_endian: bytes[1] == 1, })
}

///|
fn cdr_reader_read_u16(input : BytesView, little_endian : Bool) -> UInt {
  if little_endian {
    input[0].to_int().reinterpret_as_uint() |
    (input[1].to_int().reinterpret_as_uint() << 8)
  } else {
    (input[0].to_int().reinterpret_as_uint() << 8) |
    input[1].to_int().reinterpret_as_uint()
  }
}

///|
fn cdr_reader_read_u32(input : BytesView, little_endian : Bool) -> UInt {
  if little_endian {
    input[0].to_int().reinterpret_as_uint() |
    (input[1].to_int().reinterpret_as_uint() << 8) |
    (input[2].to_int().reinterpret_as_uint() << 16) |
    (input[3].to_int().reinterpret_as_uint() << 24)
  } else {
    (input[0].to_int().reinterpret_as_uint() << 24) |
    (input[1].to_int().reinterpret_as_uint() << 16) |
    (input[2].to_int().reinterpret_as_uint() << 8) |
    input[3].to_int().reinterpret_as_uint()
  }
}

///|
fn cdr_reader_read_u64(input : BytesView, little_endian : Bool) -> UInt64 {
  let mut value = 0UL
  for index in 0..<8 {
    let shift = if little_endian { index * 8 } else { (7 - index) * 8 }
    value = value | (input[index].to_int().to_uint64() << shift)
  }
  value
}

///|
/// Return the number of unread bytes.
pub fn Reader::remaining(self : Reader) -> Int {
  self.bytes.length() - self.offset
}

///|
/// Check for the zero-filled final padding of a CDR aggregate.
pub fn Reader::remaining_is_zero_padding(
  self : Reader,
  alignment : Int,
) -> Bool {
  let remaining = self.remaining()
  if alignment <= 0 || remaining >= alignment {
    return remaining == 0
  }
  for index in 0..<remaining {
    if self.bytes[self.offset + index] != 0 {
      return false
    }
  }
  true
}

///|
fn Reader::take(self : Reader, length : Int) -> Result[BytesView, String] {
  if length < 0 || length > self.bytes.length() - self.offset {
    return Err("truncated CDR payload")
  }
  let view = self.bytes[self.offset:self.offset + length]
  self.offset += length
  Ok(view)
}

///|
fn Reader::align(self : Reader, alignment : Int) -> Result[Unit, String] {
  // The encapsulation header is not part of the CDR stream used for
  // alignment. XCDR1 therefore aligns from the first byte after the header.
  let remainder = (self.offset - ENCAPSULATION_LENGTH) % alignment
  let padding = if remainder == 0 { 0 } else { alignment - remainder }
  match self.take(padding) {
    Ok(_) => Ok(())
    Err(message) => Err(message)
  }
}

///|
/// Read an unaligned CDR octet.
pub fn Reader::read_u8(self : Reader) -> Result[Byte, String] {
  match self.take(1) {
    Ok(view) => Ok(view[0])
    Err(message) => Err(message)
  }
}

///|
/// Read a signed CDR int8 without alignment.
pub fn Reader::read_i8(self : Reader) -> Result[Int, String] {
  match self.read_u8() {
    Ok(value) => {
      let raw = value.to_int()
      if raw >= 128 {
        Ok(raw - 256)
      } else {
        Ok(raw)
      }
    }
    Err(message) => Err(message)
  }
}

///|
/// Read a CDR boolean encoded as 0 or 1.
pub fn Reader::read_bool(self : Reader) -> Result[Bool, String] {
  match self.read_u8() {
    Ok(0) => Ok(false)
    Ok(1) => Ok(true)
    Ok(_) => Err("invalid CDR boolean")
    Err(message) => Err(message)
  }
}

///|
/// Read a signed 16-bit integer.
pub fn Reader::read_i16(self : Reader) -> Result[Int, String] {
  match self.align(2) {
    Err(message) => Err(message)
    Ok(_) =>
      match self.take(2) {
        Err(message) => Err(message)
        Ok(view) => {
          let raw = cdr_reader_read_u16(view, self.little_endian).reinterpret_as_int()
          Ok(if raw >= 32768 { raw - 65536 } else { raw })
        }
      }
  }
}

///|
/// Read an unsigned 16-bit integer.
pub fn Reader::read_u16(self : Reader) -> Result[UInt, String] {
  match self.align(2) {
    Err(message) => Err(message)
    Ok(_) =>
      match self.take(2) {
        Err(message) => Err(message)
        Ok(view) => Ok(cdr_reader_read_u16(view, self.little_endian))
      }
  }
}

///|
/// Read a signed 32-bit integer.
pub fn Reader::read_i32(self : Reader) -> Result[Int, String] {
  match self.align(4) {
    Err(message) => Err(message)
    Ok(_) =>
      match self.take(4) {
        Err(message) => Err(message)
        Ok(view) =>
          Ok(cdr_reader_read_u32(view, self.little_endian).reinterpret_as_int())
      }
  }
}

///|
/// Read an unsigned 32-bit integer.
pub fn Reader::read_u32(self : Reader) -> Result[UInt, String] {
  match self.align(4) {
    Err(message) => Err(message)
    Ok(_) =>
      match self.take(4) {
        Err(message) => Err(message)
        Ok(view) => Ok(cdr_reader_read_u32(view, self.little_endian))
      }
  }
}

///|
/// Read a signed 64-bit integer.
pub fn Reader::read_i64(self : Reader) -> Result[Int64, String] {
  match self.align(8) {
    Err(message) => Err(message)
    Ok(_) =>
      match self.take(8) {
        Err(message) => Err(message)
        Ok(view) =>
          Ok(
            cdr_reader_read_u64(view, self.little_endian).reinterpret_as_int64(),
          )
      }
  }
}

///|
/// Read an unsigned 64-bit integer.
pub fn Reader::read_u64(self : Reader) -> Result[UInt64, String] {
  match self.align(8) {
    Err(message) => Err(message)
    Ok(_) =>
      match self.take(8) {
        Err(message) => Err(message)
        Ok(view) => Ok(cdr_reader_read_u64(view, self.little_endian))
      }
  }
}

///|
/// Read an IEEE-754 single-precision value.
pub fn Reader::read_f32(self : Reader) -> Result[Float, String] {
  match self.align(4) {
    Err(message) => Err(message)
    Ok(_) =>
      match self.take(4) {
        Err(message) => Err(message)
        Ok(view) =>
          Ok(
            Float::reinterpret_from_uint(
              cdr_reader_read_u32(view, self.little_endian),
            ),
          )
      }
  }
}

///|
/// Read an IEEE-754 double-precision value.
pub fn Reader::read_f64(self : Reader) -> Result[Double, String] {
  match self.align(8) {
    Err(message) => Err(message)
    Ok(_) =>
      match self.take(8) {
        Err(message) => Err(message)
        Ok(view) =>
          Ok(
            cdr_reader_read_u64(view, self.little_endian).reinterpret_as_double(),
          )
      }
  }
}

///|
/// Read a fixed-size byte array.
pub fn Reader::read_byte_array(
  self : Reader,
  length : Int,
) -> Result[Bytes, String] {
  match self.take(length) {
    Ok(view) => Ok(view.to_owned())
    Err(message) => Err(message)
  }
}

///|
/// Read a byte sequence with a CDR uint32 length prefix.
pub fn Reader::read_byte_sequence(self : Reader) -> Result[Bytes, String] {
  let length = match self.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  self.read_byte_array(length)
}

///|
/// Read a UTF-8 CDR string and remove its terminating NUL byte.
pub fn Reader::read_string(self : Reader) -> Result[String, String] {
  let length = match self.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if length <= 0 {
    return Err("a CDR string length must include a terminating NUL")
  }
  let encoded = match self.take(length) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if encoded[length - 1] != 0 {
    return Err("a CDR string must end with NUL")
  }
  Ok(@utf8.decode(encoded[0:length - 1])) catch {
    _ => Err("invalid UTF-8 in CDR string")
  }
}

///|
/// Read a UTF-8 CDR string and enforce its maximum number of characters.
pub fn Reader::read_bounded_string(
  self : Reader,
  maximum_length : Int,
) -> Result[String, String] {
  if maximum_length < 0 {
    return Err("a CDR string bound must not be negative")
  }
  let value = match self.read_string() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if cdr_utf8_character_count(value) > maximum_length {
    return Err("CDR string exceeds its character bound")
  }
  Ok(value)
}

///|
/// Read a ROS wide string encoded as widened UTF-16 code units.
pub fn Reader::read_wstring(self : Reader) -> Result[String, String] {
  let length = match self.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if length < 0 || length > self.remaining() / 4 {
    return Err("a CDR wide string is truncated")
  }
  let encoded : Array[Byte] = []
  let mut index = 0
  while index < length {
    let first = match self.read_u32() {
      Ok(value) if value <= 0xFFFFU => value.reinterpret_as_int()
      Ok(_) => return Err("CDR wide string contains a non-UTF-16 code unit")
      Err(message) => return Err(message)
    }
    if first == 0 {
      return Err("CDR wide strings must not contain NUL")
    }
    let codepoint = if first >= 0xD800 && first <= 0xDBFF {
      if index + 1 >= length {
        return Err("CDR wide string contains an incomplete surrogate pair")
      }
      let second = match self.read_u32() {
        Ok(value) if value <= 0xFFFFU => value.reinterpret_as_int()
        Ok(_) => return Err("CDR wide string contains a non-UTF-16 code unit")
        Err(message) => return Err(message)
      }
      if second < 0xDC00 || second > 0xDFFF {
        return Err("CDR wide string contains an invalid surrogate pair")
      }
      index += 1
      0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00)
    } else if first >= 0xDC00 && first <= 0xDFFF {
      return Err("CDR wide string contains an unpaired low surrogate")
    } else {
      first
    }
    cdr_append_utf8_codepoint(encoded, codepoint)
    index += 1
  }
  Ok(@utf8.decode(Bytes::from_array(encoded))) catch {
    _ => Err("invalid UTF-16 in CDR wide string")
  }
}

///|
/// Read a UTF-16 ROS wide string and enforce its code-unit bound.
pub fn Reader::read_bounded_wstring(
  self : Reader,
  maximum_length : Int,
) -> Result[String, String] {
  if maximum_length < 0 {
    return Err("a CDR wide-string bound must not be negative")
  }
  let value = match self.read_wstring() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let units = match cdr_utf16_code_units(value) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if units.length() > maximum_length {
    return Err("CDR wide string exceeds its code-unit bound")
  }
  Ok(value)
}

///|
fn cdr_append_utf8_codepoint(output : Array[Byte], codepoint : Int) -> Unit {
  if codepoint <= 0x7F {
    output.push(codepoint.to_byte())
  } else if codepoint <= 0x7FF {
    output.push((0xC0 | (codepoint >> 6)).to_byte())
    output.push((0x80 | (codepoint & 0x3F)).to_byte())
  } else if codepoint <= 0xFFFF {
    output.push((0xE0 | (codepoint >> 12)).to_byte())
    output.push((0x80 | ((codepoint >> 6) & 0x3F)).to_byte())
    output.push((0x80 | (codepoint & 0x3F)).to_byte())
  } else {
    output.push((0xF0 | (codepoint >> 18)).to_byte())
    output.push((0x80 | ((codepoint >> 12) & 0x3F)).to_byte())
    output.push((0x80 | ((codepoint >> 6) & 0x3F)).to_byte())
    output.push((0x80 | (codepoint & 0x3F)).to_byte())
  }
}
