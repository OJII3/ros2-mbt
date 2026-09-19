///|
/// A cursor for reading a ROS 2 CDR little-endian payload.
pub struct Reader {
  bytes : Bytes
  mut offset : Int
}

///|
/// Start reading a CDR little-endian payload.
pub fn Reader::from_bytes(bytes : Bytes) -> Result[Reader, String] {
  if bytes.length() < ENCAPSULATION_LENGTH {
    return Err("a CDR payload must contain a 4-byte encapsulation header")
  }
  if bytes[0] != 0 || bytes[1] != 1 || bytes[2] != 0 || bytes[3] != 0 {
    return Err("only CDR little-endian encapsulation is supported")
  }
  Ok({ bytes, offset: ENCAPSULATION_LENGTH, })
}

///|
/// Return the number of unread bytes.
pub fn Reader::remaining(self : Reader) -> Int {
  self.bytes.length() - self.offset
}

///|
fn Reader::take(self : Reader, length : Int) -> Result[BytesView, String] {
  if length < 0 || self.offset + length > self.bytes.length() {
    return Err("truncated CDR payload")
  }
  let view = self.bytes[self.offset:self.offset + length]
  self.offset += length
  Ok(view)
}

///|
fn Reader::align(self : Reader, alignment : Int) -> Result[Unit, String] {
  let remainder = self.offset % alignment
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
        Ok(view) =>
          match view {
            [i16le(value)] => Ok(value)
            _ => Err("invalid CDR int16")
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
        Ok(view) =>
          match view {
            [u16le(value)] => Ok(value)
            _ => Err("invalid CDR uint16")
          }
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
          match view {
            [u32le(value)] => Ok(value.reinterpret_as_int())
            _ => Err("invalid CDR int32")
          }
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
        Ok(view) =>
          match view {
            [u32le(value)] => Ok(value)
            _ => Err("invalid CDR uint32")
          }
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
          match view {
            [u64le(value)] => Ok(value.reinterpret_as_int64())
            _ => Err("invalid CDR int64")
          }
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
        Ok(view) =>
          match view {
            [u64le(value)] => Ok(value)
            _ => Err("invalid CDR uint64")
          }
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
          match view {
            [u32le(value)] => Ok(Float::reinterpret_from_uint(value))
            _ => Err("invalid CDR float32")
          }
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
          match view {
            [u64le(value)] => Ok(value.reinterpret_as_double())
            _ => Err("invalid CDR float64")
          }
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
