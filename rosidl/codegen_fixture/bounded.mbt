///|
/// Generated from demo/msg/Bounded.msg
pub struct Bounded {
  values : Array[Int]
} derive(Eq, Debug)

///|
pub const Bounded_TYPE_HASH : String = "RIHS01_69505d1f37dd3187aa9337a7c6103be470f44c1341711181175e5e5e6bb951f5"

///|
pub fn Bounded::new(
  values : Array[Int],
) -> Bounded {
  {
    values,
  }
}

///|
pub fn Bounded::values(self : Bounded) -> Array[Int] {
  self.values
}

///|
pub fn Bounded::write_cdr(self : Bounded, writer : @cdr.Writer) -> Result[Unit, String] {
  if self.values.length() > 3 {
    return Err("generated ROS bounded sequence exceeds its bound")
  }
  writer.write_u32(self.values.length().reinterpret_as_uint())
  for value in self.values {
    writer.write_i32(value)
  }
  Ok(())
}

///|
pub fn Bounded::read_cdr(reader : @cdr.Reader) -> Result[Bounded, String] {
  let values_length = match reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if values_length < 0 || values_length > 3 {
    return Err("generated ROS bounded sequence exceeds its bound")
  }
  if values_length > reader.remaining() {
    return Err("generated ROS sequence is truncated")
  }
  let values : Array[Int] = []
  for _ in 0..<values_length {
    values.push(match reader.read_i32() {
      Ok(value) => value
      Err(message) => return Err(message)
    })
  }
  Ok(Bounded::new(
    values,
  ))
}

///|
pub fn Bounded::to_cdr_bytes(self : Bounded) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
pub fn Bounded::from_cdr_bytes(input : Bytes) -> Result[Bounded, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match Bounded::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}
