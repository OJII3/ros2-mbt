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
/// Create an IMU message.
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
/// Create an IMU message with zero-valued fields.
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
/// Return the IMU header.
pub fn Imu::header(self : Imu) -> @std.Header {
  self.header
}

///|
/// Return the orientation estimate.
pub fn Imu::orientation(self : Imu) -> @geometry.Quaternion {
  self.orientation
}

///|
/// Return the orientation covariance.
pub fn Imu::orientation_covariance(self : Imu) -> Array[Double] {
  self.orientation_covariance
}

///|
/// Return the angular velocity estimate.
pub fn Imu::angular_velocity(self : Imu) -> @geometry.Vector3 {
  self.angular_velocity
}

///|
/// Return the angular velocity covariance.
pub fn Imu::angular_velocity_covariance(self : Imu) -> Array[Double] {
  self.angular_velocity_covariance
}

///|
/// Return the linear acceleration estimate.
pub fn Imu::linear_acceleration(self : Imu) -> @geometry.Vector3 {
  self.linear_acceleration
}

///|
/// Return the linear acceleration covariance.
pub fn Imu::linear_acceleration_covariance(self : Imu) -> Array[Double] {
  self.linear_acceleration_covariance
}

///|
/// Serialize the IMU message as ROS 2 CDR.
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
/// Parse an IMU message from ROS 2 CDR.
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
/// Serialize the IMU message as CDR bytes.
pub fn Imu::to_cdr_bytes(self : Imu) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
/// Parse an IMU message from CDR bytes.
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
/// Create a laser scan message.
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
/// Create an empty laser scan message.
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
/// Return the laser scan header.
pub fn LaserScan::header(self : LaserScan) -> @std.Header {
  self.header
}

///|
/// Return the minimum scan angle.
pub fn LaserScan::angle_min(self : LaserScan) -> Float {
  self.angle_min
}

///|
/// Return the maximum scan angle.
pub fn LaserScan::angle_max(self : LaserScan) -> Float {
  self.angle_max
}

///|
/// Return the angular increment between measurements.
pub fn LaserScan::angle_increment(self : LaserScan) -> Float {
  self.angle_increment
}

///|
/// Return the time increment between measurements.
pub fn LaserScan::time_increment(self : LaserScan) -> Float {
  self.time_increment
}

///|
/// Return the time between scans.
pub fn LaserScan::scan_time(self : LaserScan) -> Float {
  self.scan_time
}

///|
/// Return the minimum measurable range.
pub fn LaserScan::range_min(self : LaserScan) -> Float {
  self.range_min
}

///|
/// Return the maximum measurable range.
pub fn LaserScan::range_max(self : LaserScan) -> Float {
  self.range_max
}

///|
/// Return the range measurements.
pub fn LaserScan::ranges(self : LaserScan) -> Array[Float] {
  self.ranges
}

///|
/// Return the intensity measurements.
pub fn LaserScan::intensities(self : LaserScan) -> Array[Float] {
  self.intensities
}

///|
/// Serialize the laser scan as ROS 2 CDR.
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
/// Parse a laser scan from ROS 2 CDR.
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
/// Serialize the laser scan as CDR bytes.
pub fn LaserScan::to_cdr_bytes(self : LaserScan) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
/// Parse a laser scan from CDR bytes.
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
/// Create an image message.
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
/// Create an empty image message.
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
/// Return the image header.
pub fn Image::header(self : Image) -> @std.Header {
  self.header
}

///|
/// Return the image height in pixels.
pub fn Image::height(self : Image) -> UInt {
  self.height
}

///|
/// Return the image width in pixels.
pub fn Image::width(self : Image) -> UInt {
  self.width
}

///|
/// Return the image encoding name.
pub fn Image::encoding(self : Image) -> String {
  self.encoding
}

///|
/// Return the image byte order flag.
pub fn Image::is_bigendian(self : Image) -> Byte {
  self.is_bigendian
}

///|
/// Return the image row step in bytes.
pub fn Image::step(self : Image) -> UInt {
  self.step
}

///|
/// Return the image data bytes.
pub fn Image::data(self : Image) -> Array[Byte] {
  self.data
}

///|
/// Serialize the image as ROS 2 CDR.
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
/// Parse an image from ROS 2 CDR.
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
/// Serialize the image as CDR bytes.
pub fn Image::to_cdr_bytes(self : Image) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
/// Parse an image from CDR bytes.
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
/// Create a compressed image message.
pub fn CompressedImage::new(
  header : @std.Header,
  format : String,
  data : Array[Byte],
) -> CompressedImage {
  { header, format, data, }
}

///|
/// Create an empty compressed image message.
pub fn CompressedImage::default() -> CompressedImage {
  let header : @std.Header = @std.Header::default()
  let format : String = ""
  let data : Array[Byte] = []
  CompressedImage::new(header, format, data)
}

///|
/// Return the compressed image header.
pub fn CompressedImage::header(self : CompressedImage) -> @std.Header {
  self.header
}

///|
/// Return the compressed image format.
pub fn CompressedImage::format(self : CompressedImage) -> String {
  self.format
}

///|
/// Return the compressed image data bytes.
pub fn CompressedImage::data(self : CompressedImage) -> Array[Byte] {
  self.data
}

///|
/// Serialize the compressed image as ROS 2 CDR.
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
/// Parse a compressed image from ROS 2 CDR.
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
/// Serialize the compressed image as CDR bytes.
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
/// Parse a compressed image from CDR bytes.
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
/// Create a joint state message.
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
/// Create an empty joint state message.
pub fn JointState::default() -> JointState {
  let header : @std.Header = @std.Header::default()
  let name : Array[String] = []
  let position : Array[Double] = []
  let velocity : Array[Double] = []
  let effort : Array[Double] = []
  JointState::new(header, name, position, velocity, effort)
}

///|
/// Return the joint state header.
pub fn JointState::header(self : JointState) -> @std.Header {
  self.header
}

///|
/// Return the joint names.
pub fn JointState::name(self : JointState) -> Array[String] {
  self.name
}

///|
/// Return the joint positions.
pub fn JointState::position(self : JointState) -> Array[Double] {
  self.position
}

///|
/// Return the joint velocities.
pub fn JointState::velocity(self : JointState) -> Array[Double] {
  self.velocity
}

///|
/// Return the joint efforts.
pub fn JointState::effort(self : JointState) -> Array[Double] {
  self.effort
}

///|
/// Serialize the joint state as ROS 2 CDR.
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
/// Parse a joint state from ROS 2 CDR.
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
/// Serialize the joint state as CDR bytes.
pub fn JointState::to_cdr_bytes(self : JointState) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
/// Parse a joint state from CDR bytes.
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
/// Point field datatype for signed 8-bit integers.
pub const INT8 : Byte = 1

///|
/// Point field datatype for unsigned 8-bit integers.
pub const UINT8 : Byte = 2

///|
/// Point field datatype for signed 16-bit integers.
pub const INT16 : Byte = 3

///|
/// Point field datatype for unsigned 16-bit integers.
pub const UINT16 : Byte = 4

///|
/// Point field datatype for signed 32-bit integers.
pub const INT32 : Byte = 5

///|
/// Point field datatype for unsigned 32-bit integers.
pub const UINT32 : Byte = 6

///|
/// Point field datatype for 32-bit floating-point values.
pub const FLOAT32 : Byte = 7

///|
/// Point field datatype for 64-bit floating-point values.
pub const FLOAT64 : Byte = 8

///|
/// Create a point field descriptor.
pub fn PointField::new(
  name : String,
  offset : UInt,
  datatype : Byte,
  count : UInt,
) -> PointField {
  { name, offset, datatype, count, }
}

///|
/// Create an empty point field descriptor.
pub fn PointField::default() -> PointField {
  let name : String = ""
  let offset : UInt = 0
  let datatype : Byte = 0
  let count : UInt = 0
  PointField::new(name, offset, datatype, count)
}

///|
/// Return the point field name.
pub fn PointField::name(self : PointField) -> String {
  self.name
}

///|
/// Return the point field byte offset.
pub fn PointField::offset(self : PointField) -> UInt {
  self.offset
}

///|
/// Return the point field datatype.
pub fn PointField::datatype(self : PointField) -> Byte {
  self.datatype
}

///|
/// Return the number of values in the point field.
pub fn PointField::count(self : PointField) -> UInt {
  self.count
}

///|
/// Serialize a point field as ROS 2 CDR.
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
/// Parse a point field from ROS 2 CDR.
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
/// Serialize a point field as CDR bytes.
pub fn PointField::to_cdr_bytes(self : PointField) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
/// Parse a point field from CDR bytes.
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
/// Status value for an unknown satellite fix state.
pub const STATUS_UNKNOWN : Int = -2

///|
/// Status value indicating no fix.
pub const STATUS_NO_FIX : Int = -1

///|
/// Status value indicating a standard fix.
pub const STATUS_FIX : Int = 0

///|
/// Status value indicating an SBAS fix.
pub const STATUS_SBAS_FIX : Int = 1

///|
/// Status value indicating a GBAS fix.
pub const STATUS_GBAS_FIX : Int = 2

///|
/// Service mask value for an unknown service.
pub const SERVICE_UNKNOWN : UInt = 0

///|
/// Service mask bit for GPS.
pub const SERVICE_GPS : UInt = 1

///|
/// Service mask bit for GLONASS.
pub const SERVICE_GLONASS : UInt = 2

///|
/// Service mask bit for compass-based positioning.
pub const SERVICE_COMPASS : UInt = 4

///|
/// Service mask bit for Galileo.
pub const SERVICE_GALILEO : UInt = 8

///|
/// Create a satellite navigation status message.
pub fn NavSatStatus::new(status : Int, service : UInt) -> NavSatStatus {
  { status, service, }
}

///|
/// Create a satellite navigation status with no fix.
pub fn NavSatStatus::default() -> NavSatStatus {
  let status : Int = -2
  let service : UInt = 0
  NavSatStatus::new(status, service)
}

///|
/// Return the satellite fix status.
pub fn NavSatStatus::status(self : NavSatStatus) -> Int {
  self.status
}

///|
/// Return the satellite service mask.
pub fn NavSatStatus::service(self : NavSatStatus) -> UInt {
  self.service
}

///|
/// Serialize satellite navigation status as ROS 2 CDR.
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
/// Parse satellite navigation status from ROS 2 CDR.
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
/// Serialize satellite navigation status as CDR bytes.
pub fn NavSatStatus::to_cdr_bytes(self : NavSatStatus) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
/// Parse satellite navigation status from CDR bytes.
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
/// Create a region-of-interest message.
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
/// Create an empty region-of-interest message.
pub fn RegionOfInterest::default() -> RegionOfInterest {
  let x_offset : UInt = 0
  let y_offset : UInt = 0
  let height : UInt = 0
  let width : UInt = 0
  let do_rectify : Bool = false
  RegionOfInterest::new(x_offset, y_offset, height, width, do_rectify)
}

///|
/// Return the horizontal offset.
pub fn RegionOfInterest::x_offset(self : RegionOfInterest) -> UInt {
  self.x_offset
}

///|
/// Return the vertical offset.
pub fn RegionOfInterest::y_offset(self : RegionOfInterest) -> UInt {
  self.y_offset
}

///|
/// Return the region height.
pub fn RegionOfInterest::height(self : RegionOfInterest) -> UInt {
  self.height
}

///|
/// Return the region width.
pub fn RegionOfInterest::width(self : RegionOfInterest) -> UInt {
  self.width
}

///|
/// Return whether the region should be rectified.
pub fn RegionOfInterest::do_rectify(self : RegionOfInterest) -> Bool {
  self.do_rectify
}

///|
/// Serialize the region of interest as ROS 2 CDR.
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
/// Parse a region of interest from ROS 2 CDR.
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
/// Serialize the region of interest as CDR bytes.
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
/// Parse a region of interest from CDR bytes.
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
/// Create a camera information message.
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
/// Create an empty camera information message.
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
/// Return the camera info header.
pub fn CameraInfo::header(self : CameraInfo) -> @std.Header {
  self.header
}

///|
/// Return the camera image height.
pub fn CameraInfo::height(self : CameraInfo) -> UInt {
  self.height
}

///|
/// Return the camera image width.
pub fn CameraInfo::width(self : CameraInfo) -> UInt {
  self.width
}

///|
/// Return the distortion model name.
pub fn CameraInfo::distortion_model(self : CameraInfo) -> String {
  self.distortion_model
}

///|
/// Return the distortion coefficients.
pub fn CameraInfo::d(self : CameraInfo) -> Array[Double] {
  self.d
}

///|
/// Return the intrinsic camera matrix.
pub fn CameraInfo::k(self : CameraInfo) -> Array[Double] {
  self.k
}

///|
/// Return the rectification matrix.
pub fn CameraInfo::r(self : CameraInfo) -> Array[Double] {
  self.r
}

///|
/// Return the projection matrix.
pub fn CameraInfo::p(self : CameraInfo) -> Array[Double] {
  self.p
}

///|
/// Return the horizontal binning factor.
pub fn CameraInfo::binning_x(self : CameraInfo) -> UInt {
  self.binning_x
}

///|
/// Return the vertical binning factor.
pub fn CameraInfo::binning_y(self : CameraInfo) -> UInt {
  self.binning_y
}

///|
/// Return the region of interest.
pub fn CameraInfo::roi(self : CameraInfo) -> RegionOfInterest {
  self.roi
}

///|
/// Serialize camera information as ROS 2 CDR.
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
/// Parse camera information from ROS 2 CDR.
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
/// Serialize camera information as CDR bytes.
pub fn CameraInfo::to_cdr_bytes(self : CameraInfo) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
/// Parse camera information from CDR bytes.
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
/// Create a point cloud message.
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
/// Create an empty point cloud message.
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
/// Return the point cloud header.
pub fn PointCloud2::header(self : PointCloud2) -> @std.Header {
  self.header
}

///|
/// Return the point cloud height.
pub fn PointCloud2::height(self : PointCloud2) -> UInt {
  self.height
}

///|
/// Return the point cloud width.
pub fn PointCloud2::width(self : PointCloud2) -> UInt {
  self.width
}

///|
/// Return the point field descriptors.
pub fn PointCloud2::fields(self : PointCloud2) -> Array[PointField] {
  self.fields
}

///|
/// Return the point cloud byte order flag.
pub fn PointCloud2::is_bigendian(self : PointCloud2) -> Bool {
  self.is_bigendian
}

///|
/// Return the size of one point in bytes.
pub fn PointCloud2::point_step(self : PointCloud2) -> UInt {
  self.point_step
}

///|
/// Return the size of one row in bytes.
pub fn PointCloud2::row_step(self : PointCloud2) -> UInt {
  self.row_step
}

///|
/// Return the point cloud data bytes.
pub fn PointCloud2::data(self : PointCloud2) -> Array[Byte] {
  self.data
}

///|
/// Return whether all point values are finite.
pub fn PointCloud2::is_dense(self : PointCloud2) -> Bool {
  self.is_dense
}

///|
/// Serialize the point cloud as ROS 2 CDR.
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
/// Parse a point cloud from ROS 2 CDR.
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
/// Serialize the point cloud as CDR bytes.
pub fn PointCloud2::to_cdr_bytes(self : PointCloud2) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
/// Parse a point cloud from CDR bytes.
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
pub extend Imu with Eq::{not_equal, equal}

///|
pub extend Imu with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend LaserScan with Eq::{not_equal, equal}

///|
pub extend LaserScan with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Image with Eq::{not_equal, equal}

///|
pub extend Image with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CompressedImage with Eq::{not_equal, equal}

///|
pub extend CompressedImage with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend JointState with Eq::{not_equal, equal}

///|
pub extend JointState with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend PointField with Eq::{not_equal, equal}

///|
pub extend PointField with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend NavSatStatus with Eq::{not_equal, equal}

///|
pub extend NavSatStatus with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend RegionOfInterest with Eq::{not_equal, equal}

///|
pub extend RegionOfInterest with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CameraInfo with Eq::{not_equal, equal}

///|
pub extend CameraInfo with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend PointCloud2 with Eq::{not_equal, equal}

///|
pub extend PointCloud2 with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend NavSatFix with Eq::{not_equal, equal}

///|
pub extend NavSatFix with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Covariance type is unknown.
pub const COVARIANCE_TYPE_UNKNOWN : Byte = 0

///|
/// Covariance type is approximated.
pub const COVARIANCE_TYPE_APPROXIMATED : Byte = 1

///|
/// Covariance diagonal is known.
pub const COVARIANCE_TYPE_DIAGONAL_KNOWN : Byte = 2

///|
/// Full covariance is known.
pub const COVARIANCE_TYPE_KNOWN : Byte = 3

///|
/// Create a satellite fix message.
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
/// Create a satellite fix message with zero-valued fields.
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
/// Return the satellite fix header.
pub fn NavSatFix::header(self : NavSatFix) -> @std.Header {
  self.header
}

///|
/// Return the satellite status.
pub fn NavSatFix::status(self : NavSatFix) -> NavSatStatus {
  self.status
}

///|
/// Return the latitude in degrees.
pub fn NavSatFix::latitude(self : NavSatFix) -> Double {
  self.latitude
}

///|
/// Return the longitude in degrees.
pub fn NavSatFix::longitude(self : NavSatFix) -> Double {
  self.longitude
}

///|
/// Return the altitude in meters.
pub fn NavSatFix::altitude(self : NavSatFix) -> Double {
  self.altitude
}

///|
/// Return the position covariance values.
pub fn NavSatFix::position_covariance(self : NavSatFix) -> Array[Double] {
  self.position_covariance
}

///|
/// Return the position covariance type.
pub fn NavSatFix::position_covariance_type(self : NavSatFix) -> Byte {
  self.position_covariance_type
}

///|
/// Serialize a satellite fix as ROS 2 CDR.
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
/// Parse a satellite fix from ROS 2 CDR.
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
/// Serialize a satellite fix as CDR bytes.
pub fn NavSatFix::to_cdr_bytes(self : NavSatFix) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
/// Parse a satellite fix from CDR bytes.
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
