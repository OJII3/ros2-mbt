///|
/// Return the `nav_msgs/msg/Odometry` wire identity and codecs.
pub fn Odometry::type_support() -> @endpoints.RosMessageType[Odometry] {
  @endpoints.RosMessageType::new(
    "nav_msgs",
    "msg",
    "Odometry",
    Odometry_TYPE_HASH,
    fn(message) { Odometry::to_cdr_bytes(message) },
    Odometry::from_cdr_bytes,
  )
}

///|
/// Return the `nav_msgs/msg/Path` wire identity and codecs.
pub fn Path::type_support() -> @endpoints.RosMessageType[Path] {
  @endpoints.RosMessageType::new(
    "nav_msgs",
    "msg",
    "Path",
    Path_TYPE_HASH,
    fn(message) { Path::to_cdr_bytes(message) },
    Path::from_cdr_bytes,
  )
}

///|
/// Return the `nav_msgs/msg/MapMetaData` wire identity and codecs.
pub fn MapMetaData::type_support() -> @endpoints.RosMessageType[MapMetaData] {
  @endpoints.RosMessageType::new(
    "nav_msgs",
    "msg",
    "MapMetaData",
    MapMetaData_TYPE_HASH,
    fn(message) { MapMetaData::to_cdr_bytes(message) },
    MapMetaData::from_cdr_bytes,
  )
}

///|
/// Return the `nav_msgs/msg/OccupancyGrid` wire identity and codecs.
pub fn OccupancyGrid::type_support() -> @endpoints.RosMessageType[OccupancyGrid] {
  @endpoints.RosMessageType::new(
    "nav_msgs",
    "msg",
    "OccupancyGrid",
    OccupancyGrid_TYPE_HASH,
    fn(message) { OccupancyGrid::to_cdr_bytes(message) },
    OccupancyGrid::from_cdr_bytes,
  )
}
