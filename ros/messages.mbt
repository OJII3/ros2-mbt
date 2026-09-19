///|
/// The ROS 2 `std_msgs/msg/String` message.
pub struct StringMessage {
  data : String
}

///|
pub fn StringMessage::new(data : String) -> StringMessage {
  { data, }
}

///|
pub fn StringMessage::data(self : StringMessage) -> String {
  self.data
}

///|
/// Serialize `std_msgs/msg/String` using CDR little-endian encoding.
pub fn StringMessage::to_cdr_bytes(self : StringMessage) -> Bytes {
  let writer = @cdr.Writer::new()
  writer.write_string(self.data)
  writer.to_bytes()
}

///|
/// Parse a CDR little-endian `std_msgs/msg/String` message.
pub fn StringMessage::from_cdr_bytes(
  input : Bytes,
) -> Result[StringMessage, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let data = match reader.read_string() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after std_msgs/msg/String")
  }
  Ok(StringMessage::new(data))
}

///|
/// A geometry_msgs/msg/Vector3 value.
pub struct Vector3 {
  x : Double
  y : Double
  z : Double
} derive(Eq, Debug)

///|
pub fn Vector3::new(x : Double, y : Double, z : Double) -> Vector3 {
  { x, y, z, }
}

///|
pub fn Vector3::x(self : Vector3) -> Double {
  self.x
}

///|
pub fn Vector3::y(self : Vector3) -> Double {
  self.y
}

///|
pub fn Vector3::z(self : Vector3) -> Double {
  self.z
}

///|
/// A geometry_msgs/msg/Twist value.
pub struct Twist {
  linear : Vector3
  angular : Vector3
} derive(Eq, Debug)

///|
pub fn Twist::new(linear : Vector3, angular : Vector3) -> Twist {
  { linear, angular, }
}

///|
pub fn Twist::linear(self : Twist) -> Vector3 {
  self.linear
}

///|
pub fn Twist::angular(self : Twist) -> Vector3 {
  self.angular
}

///|
/// Serialize `geometry_msgs/msg/Twist` using CDR little-endian encoding.
pub fn Twist::to_cdr_bytes(self : Twist) -> Bytes {
  let writer = @cdr.Writer::new()
  writer.write_f64(self.linear.x)
  writer.write_f64(self.linear.y)
  writer.write_f64(self.linear.z)
  writer.write_f64(self.angular.x)
  writer.write_f64(self.angular.y)
  writer.write_f64(self.angular.z)
  writer.to_bytes()
}

///|
/// Parse a CDR little-endian `geometry_msgs/msg/Twist` message.
pub fn Twist::from_cdr_bytes(input : Bytes) -> Result[Twist, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let linear_x = match reader.read_f64() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let linear_y = match reader.read_f64() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let linear_z = match reader.read_f64() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let angular_x = match reader.read_f64() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let angular_y = match reader.read_f64() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let angular_z = match reader.read_f64() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after geometry_msgs/msg/Twist")
  }
  Ok(
    Twist::new(
      Vector3::new(linear_x, linear_y, linear_z),
      Vector3::new(angular_x, angular_y, angular_z),
    ),
  )
}
