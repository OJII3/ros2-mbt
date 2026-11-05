///|
/// Generated from demo/msg/BoundedString.msg
#derive(Eq, Debug)
pub struct BoundedString {
  name : String
}

///|
pub extend BoundedString with Eq::{not_equal, equal}

///|
pub extend BoundedString with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Type hash for `demo/msg/BoundedString`.
pub const BoundedString_TYPE_HASH : String = "RIHS01_8052629c483a2c158d8ae1d74f6e52ec8e9969320cd4fab8b6680a2d8882db92"

///|
/// Create a bounded string message.
pub fn BoundedString::new(name : String) -> BoundedString {
  { name, }
}

///|
/// Return the bounded string value.
pub fn BoundedString::name(self : BoundedString) -> String {
  self.name
}

///|
/// Serialize the bounded string as ROS 2 CDR.
pub fn BoundedString::write_cdr(
  self : BoundedString,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  if writer.write_bounded_string(self.name, 3) is Err(message) {
    return Err(message)
  }
  Ok(())
}

///|
/// Parse a bounded string from ROS 2 CDR.
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
/// Serialize the bounded string as CDR bytes.
pub fn BoundedString::to_cdr_bytes(
  self : BoundedString,
) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  if self.write_cdr(writer) is Err(message) {
    return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
/// Parse a bounded string from CDR bytes.
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
