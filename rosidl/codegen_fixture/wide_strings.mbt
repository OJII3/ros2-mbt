///|
/// Generated from demo/msg/WideStrings.msg
pub struct WideStrings {
  data : String
  bounded : String
  values : Array[String]
} derive(Eq, Debug)

///|
pub extend WideStrings with Eq::{not_equal, equal}

///|
pub extend WideStrings with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Create a wide string message.
pub fn WideStrings::new(
  data : String,
  bounded : String,
  values : Array[String],
) -> WideStrings {
  { data, bounded, values, }
}

///|
/// Create the wide string message using its default values.
pub fn WideStrings::default() -> WideStrings {
  let data : String = "A猫🙂"
  let bounded : String = "🙂"
  let values : Array[String] = ["猫", "🙂"]
  WideStrings::new(data, bounded, values)
}

///|
/// Serialize the wide string message as ROS 2 CDR.
pub fn WideStrings::write_cdr(
  self : WideStrings,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  match writer.write_wstring(self.data) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match writer.write_bounded_wstring(self.bounded, 2) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  writer.write_u32(self.values.length().reinterpret_as_uint())
  for value in self.values {
    match writer.write_wstring(value) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(())
}

///|
/// Parse a wide string message from ROS 2 CDR.
pub fn WideStrings::read_cdr(
  reader : @cdr.Reader,
) -> Result[WideStrings, String] {
  let data = match reader.read_wstring() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let bounded = match reader.read_bounded_wstring(2) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let values_length = match reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if values_length < 0 || values_length > reader.remaining() {
    return Err("generated ROS sequence is truncated")
  }
  let values : Array[String] = []
  for _ in 0..<values_length {
    values.push(
      match reader.read_wstring() {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
  }
  Ok(WideStrings::new(data, bounded, values))
}

///|
/// Serialize the wide string message as CDR bytes.
pub fn WideStrings::to_cdr_bytes(self : WideStrings) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
/// Parse a wide string message from CDR bytes.
pub fn WideStrings::from_cdr_bytes(
  input : Bytes,
) -> Result[WideStrings, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match WideStrings::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}
