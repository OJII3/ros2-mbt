///|
/// Generated from nav_msgs/msg/Odometry.msg
pub struct Odometry {
  header : @std_msgs.Header
  child_frame_id : String
  pose : @geometry_msgs.PoseWithCovariance
  twist : @geometry_msgs.TwistWithCovariance
} derive(Eq, Debug)

///|
/// Create an odometry message.
pub fn Odometry::new(
  header : @std_msgs.Header,
  child_frame_id : String,
  pose : @geometry_msgs.PoseWithCovariance,
  twist : @geometry_msgs.TwistWithCovariance,
) -> Odometry {
  { header, child_frame_id, pose, twist, }
}

///|
/// Create an empty odometry message.
pub fn Odometry::default() -> Odometry {
  let header : @std_msgs.Header = @std_msgs.Header::default()
  let child_frame_id : String = ""
  let pose : @geometry_msgs.PoseWithCovariance = @geometry_msgs.PoseWithCovariance::default()
  let twist : @geometry_msgs.TwistWithCovariance = @geometry_msgs.TwistWithCovariance::default()
  Odometry::new(header, child_frame_id, pose, twist)
}

///|
/// Return the odometry header.
pub fn Odometry::header(self : Odometry) -> @std_msgs.Header {
  self.header
}

///|
/// Return the child frame identifier.
pub fn Odometry::child_frame_id(self : Odometry) -> String {
  self.child_frame_id
}

///|
/// Return the pose estimate.
pub fn Odometry::pose(self : Odometry) -> @geometry_msgs.PoseWithCovariance {
  self.pose
}

///|
/// Return the twist estimate.
pub fn Odometry::twist(self : Odometry) -> @geometry_msgs.TwistWithCovariance {
  self.twist
}

///|
/// Serialize odometry as ROS 2 CDR.
pub fn Odometry::write_cdr(
  self : Odometry,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  match self.header.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  writer.write_string(self.child_frame_id)
  match self.pose.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match self.twist.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(())
}

///|
/// Parse odometry from ROS 2 CDR.
pub fn Odometry::read_cdr(reader : @cdr.Reader) -> Result[Odometry, String] {
  let header = match @std_msgs.Header::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let child_frame_id = match reader.read_string() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let pose = match @geometry_msgs.PoseWithCovariance::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let twist = match @geometry_msgs.TwistWithCovariance::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(Odometry::new(header, child_frame_id, pose, twist))
}

///|
/// Serialize odometry as CDR bytes.
pub fn Odometry::to_cdr_bytes(self : Odometry) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
/// Parse odometry from CDR bytes.
pub fn Odometry::from_cdr_bytes(input : Bytes) -> Result[Odometry, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match Odometry::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}

///|
/// Type hash for `nav_msgs/msg/Odometry`.
pub const Odometry_TYPE_HASH : String = "RIHS01_3cc97dc7fb7502f8714462c526d369e35b603cfc34d946e3f2eda2766dfec6e0"

///|
/// Generated from nav_msgs/msg/Path.msg
pub struct Path {
  header : @std_msgs.Header
  poses : Array[@geometry_msgs.PoseStamped]
} derive(Eq, Debug)

///|
/// Create a path message.
pub fn Path::new(
  header : @std_msgs.Header,
  poses : Array[@geometry_msgs.PoseStamped],
) -> Path {
  { header, poses, }
}

///|
/// Create an empty path message.
pub fn Path::default() -> Path {
  let header : @std_msgs.Header = @std_msgs.Header::default()
  let poses : Array[@geometry_msgs.PoseStamped] = []
  Path::new(header, poses)
}

///|
/// Return the path header.
pub fn Path::header(self : Path) -> @std_msgs.Header {
  self.header
}

///|
/// Return the stamped poses in the path.
pub fn Path::poses(self : Path) -> Array[@geometry_msgs.PoseStamped] {
  self.poses
}

///|
/// Serialize the path as ROS 2 CDR.
pub fn Path::write_cdr(
  self : Path,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  match self.header.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  writer.write_u32(self.poses.length().reinterpret_as_uint())
  for value in self.poses {
    match value.write_cdr(writer) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(())
}

///|
/// Parse a path from ROS 2 CDR.
pub fn Path::read_cdr(reader : @cdr.Reader) -> Result[Path, String] {
  let header = match @std_msgs.Header::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let poses_length = match reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if poses_length < 0 {
    return Err("generated ROS sequence is truncated")
  }
  if poses_length > reader.remaining() {
    return Err("generated ROS sequence is truncated")
  }
  let poses : Array[@geometry_msgs.PoseStamped] = []
  for _ in 0..<poses_length {
    poses.push(
      match @geometry_msgs.PoseStamped::read_cdr(reader) {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
  }
  Ok(Path::new(header, poses))
}

///|
/// Serialize the path as CDR bytes.
pub fn Path::to_cdr_bytes(self : Path) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
/// Parse a path from CDR bytes.
pub fn Path::from_cdr_bytes(input : Bytes) -> Result[Path, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match Path::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}

///|
/// Type hash for `nav_msgs/msg/Path`.
pub const Path_TYPE_HASH : String = "RIHS01_1957a5bb3cee5da65c4e52e52b65a93df227efce4c20f8458b36e73066ca334b"

///|
/// Generated from nav_msgs/msg/MapMetaData.msg
pub struct MapMetaData {
  map_load_time : @builtin_interfaces.Time
  resolution : Float
  width : UInt
  height : UInt
  origin : @geometry_msgs.Pose
} derive(Eq, Debug)

///|
/// Create map metadata.
pub fn MapMetaData::new(
  map_load_time : @builtin_interfaces.Time,
  resolution : Float,
  width : UInt,
  height : UInt,
  origin : @geometry_msgs.Pose,
) -> MapMetaData {
  { map_load_time, resolution, width, height, origin, }
}

///|
/// Create empty map metadata.
pub fn MapMetaData::default() -> MapMetaData {
  let map_load_time : @builtin_interfaces.Time = @builtin_interfaces.Time::default()
  let resolution : Float = 0.0F
  let width : UInt = 0
  let height : UInt = 0
  let origin : @geometry_msgs.Pose = @geometry_msgs.Pose::default()
  MapMetaData::new(map_load_time, resolution, width, height, origin)
}

///|
/// Return the map load time.
pub fn MapMetaData::map_load_time(
  self : MapMetaData,
) -> @builtin_interfaces.Time {
  self.map_load_time
}

///|
/// Return the map resolution.
pub fn MapMetaData::resolution(self : MapMetaData) -> Float {
  self.resolution
}

///|
/// Return the map width.
pub fn MapMetaData::width(self : MapMetaData) -> UInt {
  self.width
}

///|
/// Return the map height.
pub fn MapMetaData::height(self : MapMetaData) -> UInt {
  self.height
}

///|
/// Return the map origin pose.
pub fn MapMetaData::origin(self : MapMetaData) -> @geometry_msgs.Pose {
  self.origin
}

///|
/// Serialize map metadata as ROS 2 CDR.
pub fn MapMetaData::write_cdr(
  self : MapMetaData,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  match self.map_load_time.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  writer.write_f32(self.resolution)
  writer.write_u32(self.width)
  writer.write_u32(self.height)
  match self.origin.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(())
}

///|
/// Parse map metadata from ROS 2 CDR.
pub fn MapMetaData::read_cdr(
  reader : @cdr.Reader,
) -> Result[MapMetaData, String] {
  let map_load_time = match @builtin_interfaces.Time::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let resolution = match reader.read_f32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let width = match reader.read_u32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let height = match reader.read_u32() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let origin = match @geometry_msgs.Pose::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(MapMetaData::new(map_load_time, resolution, width, height, origin))
}

///|
/// Serialize map metadata as CDR bytes.
pub fn MapMetaData::to_cdr_bytes(self : MapMetaData) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
/// Parse map metadata from CDR bytes.
pub fn MapMetaData::from_cdr_bytes(
  input : Bytes,
) -> Result[MapMetaData, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match MapMetaData::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}

///|
/// Type hash for `nav_msgs/msg/MapMetaData`.
pub const MapMetaData_TYPE_HASH : String = "RIHS01_2772d4b2000ef2b35dbaeb80fd3946c1369f817fb4f75677d916d27c17d763c8"

///|
/// Generated from nav_msgs/msg/OccupancyGrid.msg
pub struct OccupancyGrid {
  header : @std_msgs.Header
  info : MapMetaData
  data : Array[Int]
} derive(Eq, Debug)

///|
pub extend Odometry with Eq::{not_equal, equal}

///|
pub extend Odometry with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Path with Eq::{not_equal, equal}

///|
pub extend Path with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend MapMetaData with Eq::{not_equal, equal}

///|
pub extend MapMetaData with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend OccupancyGrid with Eq::{not_equal, equal}

///|
pub extend OccupancyGrid with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Create an occupancy grid.
pub fn OccupancyGrid::new(
  header : @std_msgs.Header,
  info : MapMetaData,
  data : Array[Int],
) -> OccupancyGrid {
  { header, info, data, }
}

///|
/// Create an empty occupancy grid.
pub fn OccupancyGrid::default() -> OccupancyGrid {
  let header : @std_msgs.Header = @std_msgs.Header::default()
  let info : MapMetaData = MapMetaData::default()
  let data : Array[Int] = []
  OccupancyGrid::new(header, info, data)
}

///|
/// Return the occupancy grid header.
pub fn OccupancyGrid::header(self : OccupancyGrid) -> @std_msgs.Header {
  self.header
}

///|
/// Return the map metadata.
pub fn OccupancyGrid::info(self : OccupancyGrid) -> MapMetaData {
  self.info
}

///|
/// Return the occupancy values.
pub fn OccupancyGrid::data(self : OccupancyGrid) -> Array[Int] {
  self.data
}

///|
/// Serialize the occupancy grid as ROS 2 CDR.
pub fn OccupancyGrid::write_cdr(
  self : OccupancyGrid,
  writer : @cdr.Writer,
) -> Result[Unit, String] {
  match self.header.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match self.info.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  writer.write_u32(self.data.length().reinterpret_as_uint())
  for value in self.data {
    if value < -128 || value > 127 {
      return Err("generated ROS int8 value is out of range")
    }
    writer.write_i8(value)
  }
  Ok(())
}

///|
/// Parse an occupancy grid from ROS 2 CDR.
pub fn OccupancyGrid::read_cdr(
  reader : @cdr.Reader,
) -> Result[OccupancyGrid, String] {
  let header = match @std_msgs.Header::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let info = match MapMetaData::read_cdr(reader) {
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
  let data : Array[Int] = []
  for _ in 0..<data_length {
    data.push(
      match reader.read_i8() {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
  }
  Ok(OccupancyGrid::new(header, info, data))
}

///|
/// Serialize the occupancy grid as CDR bytes.
pub fn OccupancyGrid::to_cdr_bytes(
  self : OccupancyGrid,
) -> Result[Bytes, String] {
  let writer = @cdr.Writer::new()
  match self.write_cdr(writer) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(writer.to_bytes())
}

///|
/// Parse an occupancy grid from CDR bytes.
pub fn OccupancyGrid::from_cdr_bytes(
  input : Bytes,
) -> Result[OccupancyGrid, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match OccupancyGrid::read_cdr(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if reader.remaining() != 0 {
    return Err("trailing bytes after generated ROS message")
  }
  Ok(value)
}

///|
/// Type hash for `nav_msgs/msg/OccupancyGrid`.
pub const OccupancyGrid_TYPE_HASH : String = "RIHS01_8d348150c12913a31ee0ec170fbf25089e4745d17035792a1ba94d6f0bc0cfc7"
