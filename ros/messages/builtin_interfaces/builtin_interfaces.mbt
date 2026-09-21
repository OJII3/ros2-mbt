///|
/// Generated from builtin_interfaces/msg/Time.msg
pub struct Time {
  sec : Int
  nanosec : UInt
} derive(Eq, Debug)

///|
pub const Time_TYPE_HASH : String = "RIHS01_b106235e25a4c5ed35098aa0a61a3ee9c9b18d197f398b0e4206cea9acf9c197"

///|
pub fn Time::new(sec : Int, nanosec : UInt) -> Time {
  { sec, nanosec, }
}

///|
pub fn Time::default() -> Time {
  let sec : Int = 0
  let nanosec : UInt = 0
  Time::new(sec, nanosec)
}

///|
pub fn Time::sec(self : Time) -> Int {
  self.sec
}

///|
pub fn Time::nanosec(self : Time) -> UInt {
  self.nanosec
}

///|
pub fn Time::write_cdr(
  self : Time,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  writer.write_i32(self.sec)
  writer.write_u32(self.nanosec)
  Ok(())
}

///|
pub fn Time::read_cdr(reader : @cdr.Reader) -> Result[Time, String] {
  let sec = match reader.read_i32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let nanosec = match reader.read_u32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(Time::new(sec, nanosec))
}

///|
pub fn Time::to_cdr_bytes(self : Time) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
pub fn Time::from_cdr_bytes(input : Bytes) -> Result[Time, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match Time::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}

///|
/// Generated from builtin_interfaces/msg/Duration.msg
pub struct Duration {
  sec : Int
  nanosec : UInt
} derive(Eq, Debug)

///|
pub const Duration_TYPE_HASH : String = "RIHS01_e8d009f659816f758b75334ee1a9ca5b5c0b859843261f14c7f937349599d93b"

///|
pub fn Duration::new(sec : Int, nanosec : UInt) -> Duration {
  { sec, nanosec, }
}

///|
pub fn Duration::default() -> Duration {
  let sec : Int = 0
  let nanosec : UInt = 0
  Duration::new(sec, nanosec)
}

///|
pub fn Duration::sec(self : Duration) -> Int {
  self.sec
}

///|
pub fn Duration::nanosec(self : Duration) -> UInt {
  self.nanosec
}

///|
pub fn Duration::write_cdr(
  self : Duration,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  writer.write_i32(self.sec)
  writer.write_u32(self.nanosec)
  Ok(())
}

///|
pub fn Duration::read_cdr(reader : @cdr.Reader) -> Result[Duration, String] {
  let sec = match reader.read_i32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let nanosec = match reader.read_u32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(Duration::new(sec, nanosec))
}

///|
pub fn Duration::to_cdr_bytes(self : Duration) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
pub fn Duration::from_cdr_bytes(input : Bytes) -> Result[Duration, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match Duration::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}
