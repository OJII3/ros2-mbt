///|
/// Generated from sensor_msgs/msg/Imu.msg
pub struct Imu {
  header : @std.Header
  orientation : @geometry.Quaternion
  orientation_covariance : Array[Double]
  angular_velocity : @geometry.Vector3
  angular_velocity_covariance : Array[Double]
  linear_acceleration : @geometry.Vector3
  linear_acceleration_covariance : Array[Double]
} derive(Eq, Debug)

///|
pub fn Imu::new(
  header : @std.Header,
  orientation : @geometry.Quaternion,
  orientation_covariance : Array[Double],
  angular_velocity : @geometry.Vector3,
  angular_velocity_covariance : Array[Double],
  linear_acceleration : @geometry.Vector3,
  linear_acceleration_covariance : Array[Double],
) -> Imu {
  {
    header,
    orientation,
    orientation_covariance,
    angular_velocity,
    angular_velocity_covariance,
    linear_acceleration,
    linear_acceleration_covariance,
  }
}

///|
pub fn Imu::default() -> Imu {
  let header : @std.Header = @std.Header::default()
  let orientation : @geometry.Quaternion = @geometry.Quaternion::default()
  let orientation_covariance : Array[Double] = []
  for _ in 0..<9 {
    orientation_covariance.push(0.0)
  }
  let angular_velocity : @geometry.Vector3 = @geometry.Vector3::default()
  let angular_velocity_covariance : Array[Double] = []
  for _ in 0..<9 {
    angular_velocity_covariance.push(0.0)
  }
  let linear_acceleration : @geometry.Vector3 = @geometry.Vector3::default()
  let linear_acceleration_covariance : Array[Double] = []
  for _ in 0..<9 {
    linear_acceleration_covariance.push(0.0)
  }
  Imu::new(
    header, orientation, orientation_covariance, angular_velocity, angular_velocity_covariance,
    linear_acceleration, linear_acceleration_covariance,
  )
}

///|
pub fn Imu::header(self : Imu) -> @std.Header {
  self.header
}

///|
pub fn Imu::orientation(self : Imu) -> @geometry.Quaternion {
  self.orientation
}

///|
pub fn Imu::orientation_covariance(self : Imu) -> Array[Double] {
  self.orientation_covariance
}

///|
pub fn Imu::angular_velocity(self : Imu) -> @geometry.Vector3 {
  self.angular_velocity
}

///|
pub fn Imu::angular_velocity_covariance(self : Imu) -> Array[Double] {
  self.angular_velocity_covariance
}

///|
pub fn Imu::linear_acceleration(self : Imu) -> @geometry.Vector3 {
  self.linear_acceleration
}

///|
pub fn Imu::linear_acceleration_covariance(self : Imu) -> Array[Double] {
  self.linear_acceleration_covariance
}

///|
pub fn Imu::write_cdr(self : Imu, writer : @cdr.Writer) -> Result[Unit, String] {
  if self.orientation_covariance.length() != 9 {
    return Err(
      "sensor_msgs/msg/Imu orientation_covariance must contain exactly 9 elements",
    )
  }
  if self.angular_velocity_covariance.length() != 9 {
    return Err(
      "sensor_msgs/msg/Imu angular_velocity_covariance must contain exactly 9 elements",
    )
  }
  if self.linear_acceleration_covariance.length() != 9 {
    return Err(
      "sensor_msgs/msg/Imu linear_acceleration_covariance must contain exactly 9 elements",
    )
  }
  match self.header.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match self.orientation.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  for value in self.orientation_covariance {
    writer.write_f64(value)
  }
  match self.angular_velocity.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  for value in self.angular_velocity_covariance {
    writer.write_f64(value)
  }
  match self.linear_acceleration.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  for value in self.linear_acceleration_covariance {
    writer.write_f64(value)
  }
  Ok(())
}

///|
pub fn Imu::read_cdr(reader : @cdr.Reader) -> Result[Imu, String] {
  let header = match @std.Header::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let orientation = match @geometry.Quaternion::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let orientation_covariance : Array[Double] = []
  for _ in 0..<9 {
    orientation_covariance.push(
      match reader.read_f64() {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
  }
  let angular_velocity = match @geometry.Vector3::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let angular_velocity_covariance : Array[Double] = []
  for _ in 0..<9 {
    angular_velocity_covariance.push(
      match reader.read_f64() {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
  }
  let linear_acceleration = match @geometry.Vector3::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let linear_acceleration_covariance : Array[Double] = []
  for _ in 0..<9 {
    linear_acceleration_covariance.push(
      match reader.read_f64() {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
  }
  Ok(
    Imu::new(
      header, orientation, orientation_covariance, angular_velocity, angular_velocity_covariance,
      linear_acceleration, linear_acceleration_covariance,
    ),
  )
}

///|
pub fn Imu::to_cdr_bytes(self : Imu) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
pub fn Imu::from_cdr_bytes(input : Bytes) -> Result[Imu, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match Imu::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}

///|

///|
/// Generated from sensor_msgs/msg/LaserScan.msg
pub struct LaserScan {
  header : @std.Header
  angle_min : Float
  angle_max : Float
  angle_increment : Float
  time_increment : Float
  scan_time : Float
  range_min : Float
  range_max : Float
  ranges : Array[Float]
  intensities : Array[Float]
} derive(Eq, Debug)

///|
pub fn LaserScan::new(
  header : @std.Header,
  angle_min : Float,
  angle_max : Float,
  angle_increment : Float,
  time_increment : Float,
  scan_time : Float,
  range_min : Float,
  range_max : Float,
  ranges : Array[Float],
  intensities : Array[Float],
) -> LaserScan {
  {
    header,
    angle_min,
    angle_max,
    angle_increment,
    time_increment,
    scan_time,
    range_min,
    range_max,
    ranges,
    intensities,
  }
}

///|
pub fn LaserScan::default() -> LaserScan {
  let header : @std.Header = @std.Header::default()
  let angle_min : Float = 0.0F
  let angle_max : Float = 0.0F
  let angle_increment : Float = 0.0F
  let time_increment : Float = 0.0F
  let scan_time : Float = 0.0F
  let range_min : Float = 0.0F
  let range_max : Float = 0.0F
  let ranges : Array[Float] = []
  let intensities : Array[Float] = []
  LaserScan::new(
    header, angle_min, angle_max, angle_increment, time_increment, scan_time, range_min,
    range_max, ranges, intensities,
  )
}

///|
pub fn LaserScan::header(self : LaserScan) -> @std.Header {
  self.header
}

///|
pub fn LaserScan::angle_min(self : LaserScan) -> Float {
  self.angle_min
}

///|
pub fn LaserScan::angle_max(self : LaserScan) -> Float {
  self.angle_max
}

///|
pub fn LaserScan::angle_increment(self : LaserScan) -> Float {
  self.angle_increment
}

///|
pub fn LaserScan::time_increment(self : LaserScan) -> Float {
  self.time_increment
}

///|
pub fn LaserScan::scan_time(self : LaserScan) -> Float {
  self.scan_time
}

///|
pub fn LaserScan::range_min(self : LaserScan) -> Float {
  self.range_min
}

///|
pub fn LaserScan::range_max(self : LaserScan) -> Float {
  self.range_max
}

///|
pub fn LaserScan::ranges(self : LaserScan) -> Array[Float] {
  self.ranges
}

///|
pub fn LaserScan::intensities(self : LaserScan) -> Array[Float] {
  self.intensities
}

///|
pub fn LaserScan::write_cdr(
  self : LaserScan,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  match self.header.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  writer.write_f32(self.angle_min)
  writer.write_f32(self.angle_max)
  writer.write_f32(self.angle_increment)
  writer.write_f32(self.time_increment)
  writer.write_f32(self.scan_time)
  writer.write_f32(self.range_min)
  writer.write_f32(self.range_max)
  writer.write_u32(self.ranges.length().reinterpret_as_uint())
  for value in self.ranges {
    writer.write_f32(value)
  }
  writer.write_u32(self.intensities.length().reinterpret_as_uint())
  for value in self.intensities {
    writer.write_f32(value)
  }
  Ok(())
}

///|
pub fn LaserScan::read_cdr(reader : @cdr.Reader) -> Result[LaserScan, String] {
  let header = match @std.Header::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let angle_min = match reader.read_f32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let angle_max = match reader.read_f32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let angle_increment = match reader.read_f32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let time_increment = match reader.read_f32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let scan_time = match reader.read_f32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let range_min = match reader.read_f32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let range_max = match reader.read_f32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let ranges_length = match reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if ranges_length < 0 || ranges_length > reader.remaining() {
    return Err("generated ROS sequence is truncated")
  }
  let ranges : Array[Float] = []
  for _ in 0..<ranges_length {
    ranges.push(
      match reader.read_f32() {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
  }
  let intensities_length = match reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if intensities_length < 0 || intensities_length > reader.remaining() {
    return Err("generated ROS sequence is truncated")
  }
  let intensities : Array[Float] = []
  for _ in 0..<intensities_length {
    intensities.push(
      match reader.read_f32() {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
  }
  Ok(
    LaserScan::new(
      header, angle_min, angle_max, angle_increment, time_increment, scan_time, range_min,
      range_max, ranges, intensities,
    ),
  )
}

///|
pub fn LaserScan::to_cdr_bytes(self : LaserScan) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
pub fn LaserScan::from_cdr_bytes(input : Bytes) -> Result[LaserScan, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match LaserScan::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}

///|

///|
/// Generated from sensor_msgs/msg/Image.msg
pub struct Image {
  header : @std.Header
  height : UInt
  width : UInt
  encoding : String
  is_bigendian : Byte
  step : UInt
  data : Array[Byte]
} derive(Eq, Debug)

///|
pub fn Image::new(
  header : @std.Header,
  height : UInt,
  width : UInt,
  encoding : String,
  is_bigendian : Byte,
  step : UInt,
  data : Array[Byte],
) -> Image {
  { header, height, width, encoding, is_bigendian, step, data, }
}

///|
pub fn Image::default() -> Image {
  let header : @std.Header = @std.Header::default()
  let height : UInt = 0
  let width : UInt = 0
  let encoding : String = ""
  let is_bigendian : Byte = 0
  let step : UInt = 0
  let data : Array[Byte] = []
  Image::new(header, height, width, encoding, is_bigendian, step, data)
}

///|
pub fn Image::header(self : Image) -> @std.Header {
  self.header
}

///|
pub fn Image::height(self : Image) -> UInt {
  self.height
}

///|
pub fn Image::width(self : Image) -> UInt {
  self.width
}

///|
pub fn Image::encoding(self : Image) -> String {
  self.encoding
}

///|
pub fn Image::is_bigendian(self : Image) -> Byte {
  self.is_bigendian
}

///|
pub fn Image::step(self : Image) -> UInt {
  self.step
}

///|
pub fn Image::data(self : Image) -> Array[Byte] {
  self.data
}

///|
pub fn Image::write_cdr(
  self : Image,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  match self.header.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  writer.write_u32(self.height)
  writer.write_u32(self.width)
  writer.write_string(self.encoding)
  writer.write_u8(self.is_bigendian)
  writer.write_u32(self.step)
  writer.write_u32(self.data.length().reinterpret_as_uint())
  for value in self.data {
    writer.write_u8(value)
  }
  Ok(())
}

///|
pub fn Image::read_cdr(reader : @cdr.Reader) -> Result[Image, String] {
  let header = match @std.Header::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let height = match reader.read_u32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let width = match reader.read_u32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let encoding = match reader.read_string() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let is_bigendian = match reader.read_u8() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let step = match reader.read_u32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let data_length = match reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if data_length < 0 || data_length > reader.remaining() {
    return Err("generated ROS sequence is truncated")
  }
  let data : Array[Byte] = []
  for _ in 0..<data_length {
    data.push(
      match reader.read_u8() {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
  }
  Ok(Image::new(header, height, width, encoding, is_bigendian, step, data))
}

///|
pub fn Image::to_cdr_bytes(self : Image) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
pub fn Image::from_cdr_bytes(input : Bytes) -> Result[Image, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match Image::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}

///|

///|
/// Generated from sensor_msgs/msg/CompressedImage.msg
pub struct CompressedImage {
  header : @std.Header
  format : String
  data : Array[Byte]
} derive(Eq, Debug)

///|
pub fn CompressedImage::new(
  header : @std.Header,
  format : String,
  data : Array[Byte],
) -> CompressedImage {
  { header, format, data, }
}

///|
pub fn CompressedImage::default() -> CompressedImage {
  let header : @std.Header = @std.Header::default()
  let format : String = ""
  let data : Array[Byte] = []
  CompressedImage::new(header, format, data)
}

///|
pub fn CompressedImage::header(self : CompressedImage) -> @std.Header {
  self.header
}

///|
pub fn CompressedImage::format(self : CompressedImage) -> String {
  self.format
}

///|
pub fn CompressedImage::data(self : CompressedImage) -> Array[Byte] {
  self.data
}

///|
pub fn CompressedImage::write_cdr(
  self : CompressedImage,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  match self.header.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  writer.write_string(self.format)
  writer.write_u32(self.data.length().reinterpret_as_uint())
  for value in self.data {
    writer.write_u8(value)
  }
  Ok(())
}

///|
pub fn CompressedImage::read_cdr(
  reader : @cdr.Reader,
) -> Result[CompressedImage, String] {
  let header = match @std.Header::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let format = match reader.read_string() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let data_length = match reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if data_length < 0 || data_length > reader.remaining() {
    return Err("generated ROS sequence is truncated")
  }
  let data : Array[Byte] = []
  for _ in 0..<data_length {
    data.push(
      match reader.read_u8() {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
  }
  Ok(CompressedImage::new(header, format, data))
}

///|
pub fn CompressedImage::to_cdr_bytes(
  self : CompressedImage,
) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
pub fn CompressedImage::from_cdr_bytes(
  input : Bytes,
) -> Result[CompressedImage, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match CompressedImage::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}

///|

///|
/// Generated from sensor_msgs/msg/JointState.msg
pub struct JointState {
  header : @std.Header
  name : Array[String]
  position : Array[Double]
  velocity : Array[Double]
  effort : Array[Double]
} derive(Eq, Debug)

///|
pub fn JointState::new(
  header : @std.Header,
  name : Array[String],
  position : Array[Double],
  velocity : Array[Double],
  effort : Array[Double],
) -> JointState {
  { header, name, position, velocity, effort, }
}

///|
pub fn JointState::default() -> JointState {
  let header : @std.Header = @std.Header::default()
  let name : Array[String] = []
  let position : Array[Double] = []
  let velocity : Array[Double] = []
  let effort : Array[Double] = []
  JointState::new(header, name, position, velocity, effort)
}

///|
pub fn JointState::header(self : JointState) -> @std.Header {
  self.header
}

///|
pub fn JointState::name(self : JointState) -> Array[String] {
  self.name
}

///|
pub fn JointState::position(self : JointState) -> Array[Double] {
  self.position
}

///|
pub fn JointState::velocity(self : JointState) -> Array[Double] {
  self.velocity
}

///|
pub fn JointState::effort(self : JointState) -> Array[Double] {
  self.effort
}

///|
pub fn JointState::write_cdr(
  self : JointState,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  match self.header.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  writer.write_u32(self.name.length().reinterpret_as_uint())
  for value in self.name {
    writer.write_string(value)
  }
  writer.write_u32(self.position.length().reinterpret_as_uint())
  for value in self.position {
    writer.write_f64(value)
  }
  writer.write_u32(self.velocity.length().reinterpret_as_uint())
  for value in self.velocity {
    writer.write_f64(value)
  }
  writer.write_u32(self.effort.length().reinterpret_as_uint())
  for value in self.effort {
    writer.write_f64(value)
  }
  Ok(())
}

///|
pub fn JointState::read_cdr(reader : @cdr.Reader) -> Result[JointState, String] {
  let header = match @std.Header::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let name_length = match reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if name_length < 0 || name_length > reader.remaining() {
    return Err("generated ROS sequence is truncated")
  }
  let name : Array[String] = []
  for _ in 0..<name_length {
    name.push(
      match reader.read_string() {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
  }
  let position_length = match reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if position_length < 0 || position_length > reader.remaining() {
    return Err("generated ROS sequence is truncated")
  }
  let position : Array[Double] = []
  for _ in 0..<position_length {
    position.push(
      match reader.read_f64() {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
  }
  let velocity_length = match reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if velocity_length < 0 || velocity_length > reader.remaining() {
    return Err("generated ROS sequence is truncated")
  }
  let velocity : Array[Double] = []
  for _ in 0..<velocity_length {
    velocity.push(
      match reader.read_f64() {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
  }
  let effort_length = match reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if effort_length < 0 || effort_length > reader.remaining() {
    return Err("generated ROS sequence is truncated")
  }
  let effort : Array[Double] = []
  for _ in 0..<effort_length {
    effort.push(
      match reader.read_f64() {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
  }
  Ok(JointState::new(header, name, position, velocity, effort))
}

///|
pub fn JointState::to_cdr_bytes(self : JointState) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
pub fn JointState::from_cdr_bytes(input : Bytes) -> Result[JointState, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match JointState::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}

///|

///|
/// Generated from sensor_msgs/msg/PointField.msg
pub struct PointField {
  name : String
  offset : UInt
  datatype : Byte
  count : UInt
} derive(Eq, Debug)

///|

///|
pub const INT8 : Byte = 1

///|
pub const UINT8 : Byte = 2

///|
pub const INT16 : Byte = 3

///|
pub const UINT16 : Byte = 4

///|
pub const INT32 : Byte = 5

///|
pub const UINT32 : Byte = 6

///|
pub const FLOAT32 : Byte = 7

///|
pub const FLOAT64 : Byte = 8

///|
pub fn PointField::new(
  name : String,
  offset : UInt,
  datatype : Byte,
  count : UInt,
) -> PointField {
  { name, offset, datatype, count, }
}

///|
pub fn PointField::default() -> PointField {
  let name : String = ""
  let offset : UInt = 0
  let datatype : Byte = 0
  let count : UInt = 0
  PointField::new(name, offset, datatype, count)
}

///|
pub fn PointField::name(self : PointField) -> String {
  self.name
}

///|
pub fn PointField::offset(self : PointField) -> UInt {
  self.offset
}

///|
pub fn PointField::datatype(self : PointField) -> Byte {
  self.datatype
}

///|
pub fn PointField::count(self : PointField) -> UInt {
  self.count
}

///|
pub fn PointField::write_cdr(
  self : PointField,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  writer.write_string(self.name)
  writer.write_u32(self.offset)
  writer.write_u8(self.datatype)
  writer.write_u32(self.count)
  Ok(())
}

///|
pub fn PointField::read_cdr(reader : @cdr.Reader) -> Result[PointField, String] {
  let name = match reader.read_string() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let offset = match reader.read_u32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let datatype = match reader.read_u8() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let count = match reader.read_u32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(PointField::new(name, offset, datatype, count))
}

///|
pub fn PointField::to_cdr_bytes(self : PointField) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
pub fn PointField::from_cdr_bytes(input : Bytes) -> Result[PointField, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match PointField::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}

///|
/// Generated from sensor_msgs/msg/NavSatStatus.msg
pub struct NavSatStatus {
  status : Int
  service : UInt
} derive(Eq, Debug)

///|

///|
pub const STATUS_UNKNOWN : Int = -2

///|
pub const STATUS_NO_FIX : Int = -1

///|
pub const STATUS_FIX : Int = 0

///|
pub const STATUS_SBAS_FIX : Int = 1

///|
pub const STATUS_GBAS_FIX : Int = 2

///|
pub const SERVICE_UNKNOWN : UInt = 0

///|
pub const SERVICE_GPS : UInt = 1

///|
pub const SERVICE_GLONASS : UInt = 2

///|
pub const SERVICE_COMPASS : UInt = 4

///|
pub const SERVICE_GALILEO : UInt = 8

///|
pub fn NavSatStatus::new(status : Int, service : UInt) -> NavSatStatus {
  { status, service, }
}

///|
pub fn NavSatStatus::default() -> NavSatStatus {
  let status : Int = -2
  let service : UInt = 0
  NavSatStatus::new(status, service)
}

///|
pub fn NavSatStatus::status(self : NavSatStatus) -> Int {
  self.status
}

///|
pub fn NavSatStatus::service(self : NavSatStatus) -> UInt {
  self.service
}

///|
pub fn NavSatStatus::write_cdr(
  self : NavSatStatus,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  if self.status < -128 || self.status > 127 {
    return Err("generated ROS int8 value is out of range")
  }
  writer.write_i8(self.status)
  if self.service > 65535U {
    return Err("generated ROS uint16 value is out of range")
  }
  writer.write_u16_uint(self.service)
  Ok(())
}

///|
pub fn NavSatStatus::read_cdr(
  reader : @cdr.Reader,
) -> Result[NavSatStatus, String] {
  let status = match reader.read_i8() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let service = match reader.read_u16() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(NavSatStatus::new(status, service))
}

///|
pub fn NavSatStatus::to_cdr_bytes(self : NavSatStatus) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
pub fn NavSatStatus::from_cdr_bytes(
  input : Bytes,
) -> Result[NavSatStatus, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match NavSatStatus::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}

///|
/// Generated from sensor_msgs/msg/RegionOfInterest.msg
pub struct RegionOfInterest {
  x_offset : UInt
  y_offset : UInt
  height : UInt
  width : UInt
  do_rectify : Bool
} derive(Eq, Debug)

///|

///|
pub fn RegionOfInterest::new(
  x_offset : UInt,
  y_offset : UInt,
  height : UInt,
  width : UInt,
  do_rectify : Bool,
) -> RegionOfInterest {
  { x_offset, y_offset, height, width, do_rectify, }
}

///|
pub fn RegionOfInterest::default() -> RegionOfInterest {
  let x_offset : UInt = 0
  let y_offset : UInt = 0
  let height : UInt = 0
  let width : UInt = 0
  let do_rectify : Bool = false
  RegionOfInterest::new(x_offset, y_offset, height, width, do_rectify)
}

///|
pub fn RegionOfInterest::x_offset(self : RegionOfInterest) -> UInt {
  self.x_offset
}

///|
pub fn RegionOfInterest::y_offset(self : RegionOfInterest) -> UInt {
  self.y_offset
}

///|
pub fn RegionOfInterest::height(self : RegionOfInterest) -> UInt {
  self.height
}

///|
pub fn RegionOfInterest::width(self : RegionOfInterest) -> UInt {
  self.width
}

///|
pub fn RegionOfInterest::do_rectify(self : RegionOfInterest) -> Bool {
  self.do_rectify
}

///|
pub fn RegionOfInterest::write_cdr(
  self : RegionOfInterest,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  writer.write_u32(self.x_offset)
  writer.write_u32(self.y_offset)
  writer.write_u32(self.height)
  writer.write_u32(self.width)
  writer.write_bool(self.do_rectify)
  Ok(())
}

///|
pub fn RegionOfInterest::read_cdr(
  reader : @cdr.Reader,
) -> Result[RegionOfInterest, String] {
  let x_offset = match reader.read_u32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let y_offset = match reader.read_u32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let height = match reader.read_u32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let width = match reader.read_u32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let do_rectify = match reader.read_bool() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(RegionOfInterest::new(x_offset, y_offset, height, width, do_rectify))
}

///|
pub fn RegionOfInterest::to_cdr_bytes(
  self : RegionOfInterest,
) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
pub fn RegionOfInterest::from_cdr_bytes(
  input : Bytes,
) -> Result[RegionOfInterest, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match RegionOfInterest::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}

///|
/// Generated from sensor_msgs/msg/CameraInfo.msg
pub struct CameraInfo {
  header : @std.Header
  height : UInt
  width : UInt
  distortion_model : String
  d : Array[Double]
  k : Array[Double]
  r : Array[Double]
  p : Array[Double]
  binning_x : UInt
  binning_y : UInt
  roi : RegionOfInterest
} derive(Eq, Debug)

///|
pub fn CameraInfo::new(
  header : @std.Header,
  height : UInt,
  width : UInt,
  distortion_model : String,
  d : Array[Double],
  k : Array[Double],
  r : Array[Double],
  p : Array[Double],
  binning_x : UInt,
  binning_y : UInt,
  roi : RegionOfInterest,
) -> CameraInfo {
  {
    header,
    height,
    width,
    distortion_model,
    d,
    k,
    r,
    p,
    binning_x,
    binning_y,
    roi,
  }
}

///|
pub fn CameraInfo::default() -> CameraInfo {
  let header : @std.Header = @std.Header::default()
  let height : UInt = 0
  let width : UInt = 0
  let distortion_model : String = ""
  let d : Array[Double] = []
  let k : Array[Double] = []
  for _ in 0..<9 {
    k.push(0.0)
  }
  let r : Array[Double] = []
  for _ in 0..<9 {
    r.push(0.0)
  }
  let p : Array[Double] = []
  for _ in 0..<12 {
    p.push(0.0)
  }
  let binning_x : UInt = 0
  let binning_y : UInt = 0
  let roi : RegionOfInterest = RegionOfInterest::default()
  CameraInfo::new(
    header, height, width, distortion_model, d, k, r, p, binning_x, binning_y, roi,
  )
}

///|
pub fn CameraInfo::header(self : CameraInfo) -> @std.Header {
  self.header
}

///|
pub fn CameraInfo::height(self : CameraInfo) -> UInt {
  self.height
}

///|
pub fn CameraInfo::width(self : CameraInfo) -> UInt {
  self.width
}

///|
pub fn CameraInfo::distortion_model(self : CameraInfo) -> String {
  self.distortion_model
}

///|
pub fn CameraInfo::d(self : CameraInfo) -> Array[Double] {
  self.d
}

///|
pub fn CameraInfo::k(self : CameraInfo) -> Array[Double] {
  self.k
}

///|
pub fn CameraInfo::r(self : CameraInfo) -> Array[Double] {
  self.r
}

///|
pub fn CameraInfo::p(self : CameraInfo) -> Array[Double] {
  self.p
}

///|
pub fn CameraInfo::binning_x(self : CameraInfo) -> UInt {
  self.binning_x
}

///|
pub fn CameraInfo::binning_y(self : CameraInfo) -> UInt {
  self.binning_y
}

///|
pub fn CameraInfo::roi(self : CameraInfo) -> RegionOfInterest {
  self.roi
}

///|
pub fn CameraInfo::write_cdr(
  self : CameraInfo,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  if self.k.length() != 9 {
    return Err("sensor_msgs/msg/CameraInfo k must contain exactly 9 elements")
  }
  if self.r.length() != 9 {
    return Err("sensor_msgs/msg/CameraInfo r must contain exactly 9 elements")
  }
  if self.p.length() != 12 {
    return Err("sensor_msgs/msg/CameraInfo p must contain exactly 12 elements")
  }
  match self.header.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  writer.write_u32(self.height)
  writer.write_u32(self.width)
  writer.write_string(self.distortion_model)
  writer.write_u32(self.d.length().reinterpret_as_uint())
  for value in self.d {
    writer.write_f64(value)
  }
  for value in self.k {
    writer.write_f64(value)
  }
  for value in self.r {
    writer.write_f64(value)
  }
  for value in self.p {
    writer.write_f64(value)
  }
  writer.write_u32(self.binning_x)
  writer.write_u32(self.binning_y)
  match self.roi.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(())
}

///|
pub fn CameraInfo::read_cdr(reader : @cdr.Reader) -> Result[CameraInfo, String] {
  let header = match @std.Header::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let height = match reader.read_u32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let width = match reader.read_u32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let distortion_model = match reader.read_string() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let d_length = match reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if d_length < 0 || d_length > reader.remaining() {
    return Err("generated ROS sequence is truncated")
  }
  let d : Array[Double] = []
  for _ in 0..<d_length {
    d.push(
      match reader.read_f64() {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
  }
  let k : Array[Double] = []
  for _ in 0..<9 {
    k.push(
      match reader.read_f64() {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
  }
  let r : Array[Double] = []
  for _ in 0..<9 {
    r.push(
      match reader.read_f64() {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
  }
  let p : Array[Double] = []
  for _ in 0..<12 {
    p.push(
      match reader.read_f64() {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
  }
  let binning_x = match reader.read_u32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let binning_y = match reader.read_u32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let roi = match RegionOfInterest::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(
    CameraInfo::new(
      header, height, width, distortion_model, d, k, r, p, binning_x, binning_y,
      roi,
    ),
  )
}

///|
pub fn CameraInfo::to_cdr_bytes(self : CameraInfo) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
pub fn CameraInfo::from_cdr_bytes(input : Bytes) -> Result[CameraInfo, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match CameraInfo::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}

///|

///|
/// Generated from sensor_msgs/msg/PointCloud2.msg
pub struct PointCloud2 {
  header : @std.Header
  height : UInt
  width : UInt
  fields : Array[PointField]
  is_bigendian : Bool
  point_step : UInt
  row_step : UInt
  data : Array[Byte]
  is_dense : Bool
} derive(Eq, Debug)

///|
pub fn PointCloud2::new(
  header : @std.Header,
  height : UInt,
  width : UInt,
  fields : Array[PointField],
  is_bigendian : Bool,
  point_step : UInt,
  row_step : UInt,
  data : Array[Byte],
  is_dense : Bool,
) -> PointCloud2 {
  {
    header,
    height,
    width,
    fields,
    is_bigendian,
    point_step,
    row_step,
    data,
    is_dense,
  }
}

///|
pub fn PointCloud2::default() -> PointCloud2 {
  let header : @std.Header = @std.Header::default()
  let height : UInt = 0
  let width : UInt = 0
  let fields : Array[PointField] = []
  let is_bigendian : Bool = false
  let point_step : UInt = 0
  let row_step : UInt = 0
  let data : Array[Byte] = []
  let is_dense : Bool = false
  PointCloud2::new(
    header, height, width, fields, is_bigendian, point_step, row_step, data, is_dense,
  )
}

///|
pub fn PointCloud2::header(self : PointCloud2) -> @std.Header {
  self.header
}

///|
pub fn PointCloud2::height(self : PointCloud2) -> UInt {
  self.height
}

///|
pub fn PointCloud2::width(self : PointCloud2) -> UInt {
  self.width
}

///|
pub fn PointCloud2::fields(self : PointCloud2) -> Array[PointField] {
  self.fields
}

///|
pub fn PointCloud2::is_bigendian(self : PointCloud2) -> Bool {
  self.is_bigendian
}

///|
pub fn PointCloud2::point_step(self : PointCloud2) -> UInt {
  self.point_step
}

///|
pub fn PointCloud2::row_step(self : PointCloud2) -> UInt {
  self.row_step
}

///|
pub fn PointCloud2::data(self : PointCloud2) -> Array[Byte] {
  self.data
}

///|
pub fn PointCloud2::is_dense(self : PointCloud2) -> Bool {
  self.is_dense
}

///|
pub fn PointCloud2::write_cdr(
  self : PointCloud2,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  match self.header.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  writer.write_u32(self.height)
  writer.write_u32(self.width)
  writer.write_u32(self.fields.length().reinterpret_as_uint())
  for value in self.fields {
    match value.write_cdr(writer) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  writer.write_bool(self.is_bigendian)
  writer.write_u32(self.point_step)
  writer.write_u32(self.row_step)
  writer.write_u32(self.data.length().reinterpret_as_uint())
  for value in self.data {
    writer.write_u8(value)
  }
  writer.write_bool(self.is_dense)
  Ok(())
}

///|
pub fn PointCloud2::read_cdr(
  reader : @cdr.Reader,
) -> Result[PointCloud2, String] {
  let header = match @std.Header::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let height = match reader.read_u32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let width = match reader.read_u32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let fields_length = match reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if fields_length < 0 {
    return Err("generated ROS sequence is truncated")
  }
  if fields_length > reader.remaining() {
    return Err("generated ROS sequence is truncated")
  }
  let fields : Array[PointField] = []
  for _ in 0..<fields_length {
    fields.push(
      match PointField::read_cdr(reader) {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
  }
  let is_bigendian = match reader.read_bool() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let point_step = match reader.read_u32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let row_step = match reader.read_u32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let data_length = match reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if data_length < 0 || data_length > reader.remaining() {
    return Err("generated ROS sequence is truncated")
  }
  let data : Array[Byte] = []
  for _ in 0..<data_length {
    data.push(
      match reader.read_u8() {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
  }
  let is_dense = match reader.read_bool() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(
    PointCloud2::new(
      header, height, width, fields, is_bigendian, point_step, row_step, data, is_dense,
    ),
  )
}

///|
pub fn PointCloud2::to_cdr_bytes(self : PointCloud2) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
pub fn PointCloud2::from_cdr_bytes(
  input : Bytes,
) -> Result[PointCloud2, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match PointCloud2::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}

///|

///|
/// Generated from sensor_msgs/msg/NavSatFix.msg
pub struct NavSatFix {
  header : @std.Header
  status : NavSatStatus
  latitude : Double
  longitude : Double
  altitude : Double
  position_covariance : Array[Double]
  position_covariance_type : Byte
} derive(Eq, Debug)

///|
pub const COVARIANCE_TYPE_UNKNOWN : Byte = 0

///|
pub const COVARIANCE_TYPE_APPROXIMATED : Byte = 1

///|
pub const COVARIANCE_TYPE_DIAGONAL_KNOWN : Byte = 2

///|
pub const COVARIANCE_TYPE_KNOWN : Byte = 3

///|
pub fn NavSatFix::new(
  header : @std.Header,
  status : NavSatStatus,
  latitude : Double,
  longitude : Double,
  altitude : Double,
  position_covariance : Array[Double],
  position_covariance_type : Byte,
) -> NavSatFix {
  {
    header,
    status,
    latitude,
    longitude,
    altitude,
    position_covariance,
    position_covariance_type,
  }
}

///|
pub fn NavSatFix::default() -> NavSatFix {
  let header : @std.Header = @std.Header::default()
  let status : NavSatStatus = NavSatStatus::default()
  let latitude : Double = 0.0
  let longitude : Double = 0.0
  let altitude : Double = 0.0
  let position_covariance : Array[Double] = []
  for _ in 0..<9 {
    position_covariance.push(0.0)
  }
  let position_covariance_type : Byte = 0
  NavSatFix::new(
    header, status, latitude, longitude, altitude, position_covariance, position_covariance_type,
  )
}

///|
pub fn NavSatFix::header(self : NavSatFix) -> @std.Header {
  self.header
}

///|
pub fn NavSatFix::status(self : NavSatFix) -> NavSatStatus {
  self.status
}

///|
pub fn NavSatFix::latitude(self : NavSatFix) -> Double {
  self.latitude
}

///|
pub fn NavSatFix::longitude(self : NavSatFix) -> Double {
  self.longitude
}

///|
pub fn NavSatFix::altitude(self : NavSatFix) -> Double {
  self.altitude
}

///|
pub fn NavSatFix::position_covariance(self : NavSatFix) -> Array[Double] {
  self.position_covariance
}

///|
pub fn NavSatFix::position_covariance_type(self : NavSatFix) -> Byte {
  self.position_covariance_type
}

///|
pub fn NavSatFix::write_cdr(
  self : NavSatFix,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  if self.position_covariance.length() != 9 {
    return Err(
      "sensor_msgs/msg/NavSatFix position_covariance must contain exactly 9 elements",
    )
  }
  match self.header.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match self.status.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  writer.write_f64(self.latitude)
  writer.write_f64(self.longitude)
  writer.write_f64(self.altitude)
  for value in self.position_covariance {
    writer.write_f64(value)
  }
  writer.write_u8(self.position_covariance_type)
  Ok(())
}

///|
pub fn NavSatFix::read_cdr(reader : @cdr.Reader) -> Result[NavSatFix, String] {
  let header = match @std.Header::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let status = match NavSatStatus::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let latitude = match reader.read_f64() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let longitude = match reader.read_f64() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let altitude = match reader.read_f64() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let position_covariance : Array[Double] = []
  for _ in 0..<9 {
    position_covariance.push(
      match reader.read_f64() {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
  }
  let position_covariance_type = match reader.read_u8() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(
    NavSatFix::new(
      header, status, latitude, longitude, altitude, position_covariance, position_covariance_type,
    ),
  )
}

///|
pub fn NavSatFix::to_cdr_bytes(self : NavSatFix) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
pub fn NavSatFix::from_cdr_bytes(input : Bytes) -> Result[NavSatFix, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match NavSatFix::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}

///|

///|
pub const Imu_TYPE_HASH : String = "RIHS01_7d9a00ff131080897a5ec7e26e315954b8eae3353c3f995c55faf71574000b5b"

///|
pub const LaserScan_TYPE_HASH : String = "RIHS01_64c191398013af96509d518dac71d5164f9382553fce5c1f8cca5be7924bd828"

///|
pub const Image_TYPE_HASH : String = "RIHS01_d31d41a9a4c4bc8eae9be757b0beed306564f7526c88ea6a4588fb9582527d47"

///|
pub const CompressedImage_TYPE_HASH : String = "RIHS01_15640771531571185e2efc8a100baf923961a4d15d5569652e6cb6691e8e371a"

///|
pub const CameraInfo_TYPE_HASH : String = "RIHS01_b3dfd68ff46c9d56c80fd3bd4ed22c7a4ddce8c8348f2f59c299e73118e7e275"

///|
pub const JointState_TYPE_HASH : String = "RIHS01_a13ee3a330e346c9d87b5aa18d24e11690752bd33a0350f11c5882bc9179260e"

///|
pub const PointCloud2_TYPE_HASH : String = "RIHS01_9198cabf7da3796ae6fe19c4cb3bdd3525492988c70522628af5daa124bae2b5"

///|
pub const PointField_TYPE_HASH : String = "RIHS01_5c6a4750728c2bcfbbf7037225b20b02d4429634732146b742dee1726637ef01"

///|
pub const NavSatFix_TYPE_HASH : String = "RIHS01_62223ab3fe210a15976021da7afddc9e200dc9ec75231c1b6a557fc598a65404"

///|
pub const NavSatStatus_TYPE_HASH : String = "RIHS01_d1ed3befa628e09571bd273b888ba1c1fd187c9a5e0006b385d7e5e9095a3204"

///|
pub const RegionOfInterest_TYPE_HASH : String = "RIHS01_ad16bcba5f9131dcdba6fbded19f726f5440e3c513b4fb586dd3027eeed8abb1"
