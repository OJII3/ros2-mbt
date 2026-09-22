///|
/// Generated from std_msgs/msg/Header.msg
pub struct Header {
  stamp : @builtin_interfaces.Time
  frame_id : String
} derive(Eq, Debug)

///|
pub extend Header with Eq::{not_equal, equal}

///|
pub extend Header with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Create a standard message header.
pub fn Header::new(
  stamp : @builtin_interfaces.Time,
  frame_id : String,
) -> Header {
  { stamp, frame_id, }
}

///|
/// Create an empty standard message header.
pub fn Header::default() -> Header {
  let stamp : @builtin_interfaces.Time = @builtin_interfaces.Time::default()
  let frame_id : String = ""
  Header::new(stamp, frame_id)
}

///|
/// Return the header timestamp.
pub fn Header::stamp(self : Header) -> @builtin_interfaces.Time {
  self.stamp
}

///|
/// Return the header frame identifier.
pub fn Header::frame_id(self : Header) -> String {
  self.frame_id
}

///|
/// Serialize the header as ROS 2 CDR.
pub fn Header::write_cdr(
  self : Header,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  match self.stamp.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  writer.write_string(self.frame_id)
  Ok(())
}

///|
/// Parse a header from ROS 2 CDR.
pub fn Header::read_cdr(reader : @cdr.Reader) -> Result[Header, String] {
  let stamp = match @builtin_interfaces.Time::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let frame_id = match reader.read_string() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(Header::new(stamp, frame_id))
}

///|
/// Serialize the header as CDR bytes.
pub fn Header::to_cdr_bytes(self : Header) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
/// Parse a header from CDR bytes.
pub fn Header::from_cdr_bytes(input : Bytes) -> Result[Header, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match Header::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}

///|
/// Type hash for `std_msgs/msg/Header`.
pub const Header_TYPE_HASH : String = "RIHS01_f49fb3ae2cf070f793645ff749683ac6b06203e41c891e17701b1cb597ce6a01"
