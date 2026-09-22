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
pub fn Vector3::default() -> Vector3 {
  Vector3::new(0.0, 0.0, 0.0)
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
/// Write a `geometry_msgs/msg/Vector3` value into an existing CDR stream.
pub fn Vector3::write_cdr(
  self : Vector3,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  writer.write_f64(self.x)
  writer.write_f64(self.y)
  writer.write_f64(self.z)
  Ok(())
}

///|
/// Read a `geometry_msgs/msg/Vector3` value from an existing CDR stream.
pub fn Vector3::read_cdr(reader : @cdr.Reader) -> Result[Vector3, String] {
  let x = match reader.read_f64() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let y = match reader.read_f64() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let z = match reader.read_f64() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(Vector3::new(x, y, z))
}

///|
/// Serialize `geometry_msgs/msg/Vector3` using CDR little-endian encoding.
pub fn Vector3::to_cdr_bytes(self : Vector3) -> Bytes {
  let writer = @cdr.Writer::new()
  self.write_cdr(writer).unwrap()
  writer.to_bytes()
}

///|
/// Parse a CDR little-endian `geometry_msgs/msg/Vector3` message.
pub fn Vector3::from_cdr_bytes(input : Bytes) -> Result[Vector3, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let vector = match Vector3::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if !reader.remaining_is_zero_padding(8) {
    return Err("trailing bytes after geometry_msgs/msg/Vector3")
  }
  Ok(vector)
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
pub fn Twist::default() -> Twist {
  Twist::new(Vector3::default(), Vector3::default())
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
/// Write a `geometry_msgs/msg/Twist` value into an existing CDR stream.
pub fn Twist::write_cdr(
  self : Twist,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  match self.linear.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  self.angular.write_cdr(writer)
}

///|
/// Read a `geometry_msgs/msg/Twist` value from an existing CDR stream.
pub fn Twist::read_cdr(reader : @cdr.Reader) -> Result[Twist, String] {
  let linear = match Vector3::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let angular = match Vector3::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(Twist::new(linear, angular))
}

///|
/// Serialize `geometry_msgs/msg/Twist` using CDR little-endian encoding.
pub fn Twist::to_cdr_bytes(self : Twist) -> Bytes {
  let writer = @cdr.Writer::new()
  self.write_cdr(writer).unwrap()
  writer.to_bytes()
}

///|
/// Parse a CDR little-endian `geometry_msgs/msg/Twist` message.
pub fn Twist::from_cdr_bytes(input : Bytes) -> Result[Twist, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let twist = match Twist::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if !reader.remaining_is_zero_padding(8) {
    return Err("trailing bytes after geometry_msgs/msg/Twist")
  }
  Ok(twist)
}

///|
/// Generated from geometry_msgs/msg/Point.msg
pub struct Point {
  x : Double
  y : Double
  z : Double
} derive(Eq, Debug)

///|
pub const Point_TYPE_HASH : String = "RIHS01_6963084842a9b04494d6b2941d11444708d892da2f4b09843b9c43f42a7f6881"

///|
pub fn Point::new(x : Double, y : Double, z : Double) -> Point {
  { x, y, z, }
}

///|
pub fn Point::default() -> Point {
  let x : Double = 0.0
  let y : Double = 0.0
  let z : Double = 0.0
  Point::new(x, y, z)
}

///|
pub fn Point::x(self : Point) -> Double {
  self.x
}

///|
pub fn Point::y(self : Point) -> Double {
  self.y
}

///|
pub fn Point::z(self : Point) -> Double {
  self.z
}

///|
pub fn Point::write_cdr(
  self : Point,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  writer.write_f64(self.x)
  writer.write_f64(self.y)
  writer.write_f64(self.z)
  Ok(())
}

///|
pub fn Point::read_cdr(reader : @cdr.Reader) -> Result[Point, String] {
  let x = match reader.read_f64() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let y = match reader.read_f64() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let z = match reader.read_f64() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(Point::new(x, y, z))
}

///|
pub fn Point::to_cdr_bytes(self : Point) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
pub fn Point::from_cdr_bytes(input : Bytes) -> Result[Point, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match Point::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}

///|
/// Generated from geometry_msgs/msg/Quaternion.msg
pub struct Quaternion {
  x : Double
  y : Double
  z : Double
  w : Double
} derive(Eq, Debug)

///|
pub const Quaternion_TYPE_HASH : String = "RIHS01_8a765f66778c8ff7c8ab94afcc590a2ed5325a1d9a076ffff38fbce36f458684"

///|
pub fn Quaternion::new(
  x : Double,
  y : Double,
  z : Double,
  w : Double,
) -> Quaternion {
  { x, y, z, w, }
}

///|
pub fn Quaternion::default() -> Quaternion {
  let x : Double = 0.0
  let y : Double = 0.0
  let z : Double = 0.0
  let w : Double = 1.0
  Quaternion::new(x, y, z, w)
}

///|
pub fn Quaternion::x(self : Quaternion) -> Double {
  self.x
}

///|
pub fn Quaternion::y(self : Quaternion) -> Double {
  self.y
}

///|
pub fn Quaternion::z(self : Quaternion) -> Double {
  self.z
}

///|
pub fn Quaternion::w(self : Quaternion) -> Double {
  self.w
}

///|
pub fn Quaternion::write_cdr(
  self : Quaternion,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  writer.write_f64(self.x)
  writer.write_f64(self.y)
  writer.write_f64(self.z)
  writer.write_f64(self.w)
  Ok(())
}

///|
pub fn Quaternion::read_cdr(reader : @cdr.Reader) -> Result[Quaternion, String] {
  let x = match reader.read_f64() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let y = match reader.read_f64() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let z = match reader.read_f64() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let w = match reader.read_f64() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(Quaternion::new(x, y, z, w))
}

///|
pub fn Quaternion::to_cdr_bytes(self : Quaternion) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
pub fn Quaternion::from_cdr_bytes(input : Bytes) -> Result[Quaternion, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match Quaternion::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}

///|
/// Generated from geometry_msgs/msg/Pose.msg
pub struct Pose {
  position : Point
  orientation : Quaternion
} derive(Eq, Debug)

///|
pub fn Pose::new(position : Point, orientation : Quaternion) -> Pose {
  { position, orientation, }
}

///|
pub fn Pose::default() -> Pose {
  let position : Point = Point::default()
  let orientation : Quaternion = Quaternion::default()
  Pose::new(position, orientation)
}

///|
pub fn Pose::position(self : Pose) -> Point {
  self.position
}

///|
pub fn Pose::orientation(self : Pose) -> Quaternion {
  self.orientation
}

///|
pub fn Pose::write_cdr(
  self : Pose,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  match self.position.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match self.orientation.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(())
}

///|
pub fn Pose::read_cdr(reader : @cdr.Reader) -> Result[Pose, String] {
  let position = match Point::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let orientation = match Quaternion::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(Pose::new(position, orientation))
}

///|
pub fn Pose::to_cdr_bytes(self : Pose) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
pub fn Pose::from_cdr_bytes(input : Bytes) -> Result[Pose, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match Pose::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}

///|
pub const Pose_TYPE_HASH : String = "RIHS01_d501954e9476cea2996984e812054b68026ae0bfae789d9a10b23daf35cc90fa"

///|
/// Generated from geometry_msgs/msg/Transform.msg
pub struct Transform {
  translation : Vector3
  rotation : Quaternion
} derive(Eq, Debug)

///|
pub fn Transform::new(
  translation : Vector3,
  rotation : Quaternion,
) -> Transform {
  { translation, rotation, }
}

///|
pub fn Transform::default() -> Transform {
  let translation : Vector3 = Vector3::default()
  let rotation : Quaternion = Quaternion::default()
  Transform::new(translation, rotation)
}

///|
pub fn Transform::translation(self : Transform) -> Vector3 {
  self.translation
}

///|
pub fn Transform::rotation(self : Transform) -> Quaternion {
  self.rotation
}

///|
pub fn Transform::write_cdr(
  self : Transform,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  match self.translation.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match self.rotation.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(())
}

///|
pub fn Transform::read_cdr(reader : @cdr.Reader) -> Result[Transform, String] {
  let translation = match Vector3::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let rotation = match Quaternion::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(Transform::new(translation, rotation))
}

///|
pub fn Transform::to_cdr_bytes(self : Transform) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
pub fn Transform::from_cdr_bytes(input : Bytes) -> Result[Transform, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match Transform::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}

///|
pub const Transform_TYPE_HASH : String = "RIHS01_beb83fbe698636351461f6f35d1abb20010c43d55374d81bd041f1ba2581fddc"

///|
/// Generated from geometry_msgs/msg/TransformStamped.msg
pub struct TransformStamped {
  header : @std_msgs.Header
  child_frame_id : String
  transform : Transform
} derive(Eq, Debug)

///|
pub fn TransformStamped::new(
  header : @std_msgs.Header,
  child_frame_id : String,
  transform : Transform,
) -> TransformStamped {
  { header, child_frame_id, transform, }
}

///|
pub fn TransformStamped::default() -> TransformStamped {
  let header : @std_msgs.Header = @std_msgs.Header::default()
  let child_frame_id : String = ""
  let transform : Transform = Transform::default()
  TransformStamped::new(header, child_frame_id, transform)
}

///|
pub fn TransformStamped::header(self : TransformStamped) -> @std_msgs.Header {
  self.header
}

///|
pub fn TransformStamped::child_frame_id(self : TransformStamped) -> String {
  self.child_frame_id
}

///|
pub fn TransformStamped::transform(self : TransformStamped) -> Transform {
  self.transform
}

///|
pub fn TransformStamped::write_cdr(
  self : TransformStamped,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  match self.header.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  writer.write_string(self.child_frame_id)
  match self.transform.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(())
}

///|
pub fn TransformStamped::read_cdr(
  reader : @cdr.Reader,
) -> Result[TransformStamped, String] {
  let header = match @std_msgs.Header::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let child_frame_id = match reader.read_string() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let transform = match Transform::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(TransformStamped::new(header, child_frame_id, transform))
}

///|
pub fn TransformStamped::to_cdr_bytes(
  self : TransformStamped,
) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
pub fn TransformStamped::from_cdr_bytes(
  input : Bytes,
) -> Result[TransformStamped, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match TransformStamped::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}

///|
pub const TransformStamped_TYPE_HASH : String = "RIHS01_0a241f87d04668d94099cbb5ba11691d5ad32c2f29682e4eb5653424bd275206"

///|
/// Generated from geometry_msgs/msg/PoseStamped.msg
pub struct PoseStamped {
  header : @std_msgs.Header
  pose : Pose
} derive(Eq, Debug)

///|
pub fn PoseStamped::new(header : @std_msgs.Header, pose : Pose) -> PoseStamped {
  { header, pose, }
}

///|
pub fn PoseStamped::default() -> PoseStamped {
  let header : @std_msgs.Header = @std_msgs.Header::default()
  let pose : Pose = Pose::default()
  PoseStamped::new(header, pose)
}

///|
pub fn PoseStamped::header(self : PoseStamped) -> @std_msgs.Header {
  self.header
}

///|
pub fn PoseStamped::pose(self : PoseStamped) -> Pose {
  self.pose
}

///|
pub fn PoseStamped::write_cdr(
  self : PoseStamped,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  match self.header.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match self.pose.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(())
}

///|
pub fn PoseStamped::read_cdr(
  reader : @cdr.Reader,
) -> Result[PoseStamped, String] {
  let header = match @std_msgs.Header::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let pose = match Pose::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(PoseStamped::new(header, pose))
}

///|
pub fn PoseStamped::to_cdr_bytes(self : PoseStamped) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
pub fn PoseStamped::from_cdr_bytes(
  input : Bytes,
) -> Result[PoseStamped, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match PoseStamped::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}

///|
pub const PoseStamped_TYPE_HASH : String = "RIHS01_10f3786d7d40fd2b54367835614bff85d4ad3b5dab62bf8bca0cc232d73b4cd8"

///|
/// Generated from geometry_msgs/msg/PoseWithCovariance.msg
pub struct PoseWithCovariance {
  pose : Pose
  covariance : Array[Double]
} derive(Eq, Debug)

///|
pub fn PoseWithCovariance::new(
  pose : Pose,
  covariance : Array[Double],
) -> PoseWithCovariance {
  { pose, covariance, }
}

///|
pub fn PoseWithCovariance::default() -> PoseWithCovariance {
  let pose : Pose = Pose::default()
  let covariance : Array[Double] = []
  for _ in 0..<36 {
    covariance.push(0.0)
  }
  PoseWithCovariance::new(pose, covariance)
}

///|
pub fn PoseWithCovariance::pose(self : PoseWithCovariance) -> Pose {
  self.pose
}

///|
pub fn PoseWithCovariance::covariance(
  self : PoseWithCovariance,
) -> Array[Double] {
  self.covariance
}

///|
pub fn PoseWithCovariance::write_cdr(
  self : PoseWithCovariance,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  if self.covariance.length() != 36 {
    return Err("PoseWithCovariance covariance must contain exactly 36 values")
  }
  match self.pose.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  for value in self.covariance {
    writer.write_f64(value)
  }
  Ok(())
}

///|
pub fn PoseWithCovariance::read_cdr(
  reader : @cdr.Reader,
) -> Result[PoseWithCovariance, String] {
  let pose = match Pose::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let covariance : Array[Double] = []
  for _ in 0..<36 {
    covariance.push(
      match reader.read_f64() {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
  }
  Ok(PoseWithCovariance::new(pose, covariance))
}

///|
pub fn PoseWithCovariance::to_cdr_bytes(
  self : PoseWithCovariance,
) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
pub fn PoseWithCovariance::from_cdr_bytes(
  input : Bytes,
) -> Result[PoseWithCovariance, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match PoseWithCovariance::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}

///|
pub const PoseWithCovariance_TYPE_HASH : String = "RIHS01_9a7c0fd234b7f45c6098745ecccd773ca1085670e64107135397aee31c02e1bb"

///|
/// Generated from geometry_msgs/msg/TwistWithCovariance.msg
pub struct TwistWithCovariance {
  twist : Twist
  covariance : Array[Double]
} derive(Eq, Debug)

///|
pub extend Vector3 with Eq::{not_equal, equal}

///|
pub extend Vector3 with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Twist with Eq::{not_equal, equal}

///|
pub extend Twist with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Point with Eq::{not_equal, equal}

///|
pub extend Point with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Quaternion with Eq::{not_equal, equal}

///|
pub extend Quaternion with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Pose with Eq::{not_equal, equal}

///|
pub extend Pose with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Transform with Eq::{not_equal, equal}

///|
pub extend Transform with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend TransformStamped with Eq::{not_equal, equal}

///|
pub extend TransformStamped with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend PoseStamped with Eq::{not_equal, equal}

///|
pub extend PoseStamped with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend PoseWithCovariance with Eq::{not_equal, equal}

///|
pub extend PoseWithCovariance with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend TwistWithCovariance with Eq::{not_equal, equal}

///|
pub extend TwistWithCovariance with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub fn TwistWithCovariance::new(
  twist : Twist,
  covariance : Array[Double],
) -> TwistWithCovariance {
  { twist, covariance, }
}

///|
pub fn TwistWithCovariance::default() -> TwistWithCovariance {
  let twist : Twist = Twist::default()
  let covariance : Array[Double] = []
  for _ in 0..<36 {
    covariance.push(0.0)
  }
  TwistWithCovariance::new(twist, covariance)
}

///|
pub fn TwistWithCovariance::twist(self : TwistWithCovariance) -> Twist {
  self.twist
}

///|
pub fn TwistWithCovariance::covariance(
  self : TwistWithCovariance,
) -> Array[Double] {
  self.covariance
}

///|
pub fn TwistWithCovariance::write_cdr(
  self : TwistWithCovariance,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  if self.covariance.length() != 36 {
    return Err("TwistWithCovariance covariance must contain exactly 36 values")
  }
  match self.twist.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  for value in self.covariance {
    writer.write_f64(value)
  }
  Ok(())
}

///|
pub fn TwistWithCovariance::read_cdr(
  reader : @cdr.Reader,
) -> Result[TwistWithCovariance, String] {
  let twist = match Twist::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let covariance : Array[Double] = []
  for _ in 0..<36 {
    covariance.push(
      match reader.read_f64() {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
  }
  Ok(TwistWithCovariance::new(twist, covariance))
}

///|
pub fn TwistWithCovariance::to_cdr_bytes(
  self : TwistWithCovariance,
) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
pub fn TwistWithCovariance::from_cdr_bytes(
  input : Bytes,
) -> Result[TwistWithCovariance, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match TwistWithCovariance::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}

///|
pub const TwistWithCovariance_TYPE_HASH : String = "RIHS01_49f574f033f095d8b6cd1beaca5ca7925e296e84af1716d16c89d38b059c8c18"
