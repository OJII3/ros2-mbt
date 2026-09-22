///|
/// Generated from demo/msg/BoundedString.msg
pub struct BoundedString {
  name : String
} derive(Eq, Debug)

///|
pub extend BoundedString with Eq::{not_equal, equal}

///|
pub extend BoundedString with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub const BoundedString_TYPE_HASH : String = "RIHS01_8052629c483a2c158d8ae1d74f6e52ec8e9969320cd4fab8b6680a2d8882db92"

///|
pub fn BoundedString::new(name : String) -> BoundedString {
  { name, }
}

///|
pub fn BoundedString::name(self : BoundedString) -> String {
  self.name
}

///|
pub fn BoundedString::write_cdr(
  self : BoundedString,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  match writer.write_bounded_string(self.name, 3) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(())
}

///|
pub fn BoundedString::read_cdr(
  reader : @cdr.Reader,
) -> Result[BoundedString, String] {
  let name = match reader.read_bounded_string(3) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(BoundedString::new(name))
}

///|
pub fn BoundedString::to_cdr_bytes(
  self : BoundedString,
) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
pub fn BoundedString::from_cdr_bytes(
  input : Bytes,
) -> Result[BoundedString, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match BoundedString::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}
