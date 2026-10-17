///|
/// Return the `sensor_msgs/msg/Imu` wire identity and codecs.
pub fn Imu::type_support() -> @endpoints.RosMessageType[Imu] {
  @endpoints.RosMessageType::new(
    "sensor_msgs",
    "msg",
    "Imu",
    Imu_TYPE_HASH,
    fn(message) { Imu::to_cdr_bytes(message) },
    Imu::from_cdr_bytes,
  )
}

///|
/// Return the `sensor_msgs/msg/LaserScan` wire identity and codecs.
pub fn LaserScan::type_support() -> @endpoints.RosMessageType[LaserScan] {
  @endpoints.RosMessageType::new(
    "sensor_msgs",
    "msg",
    "LaserScan",
    LaserScan_TYPE_HASH,
    fn(message) { LaserScan::to_cdr_bytes(message) },
    LaserScan::from_cdr_bytes,
  )
}

///|
/// Return the `sensor_msgs/msg/Image` wire identity and codecs.
pub fn Image::type_support() -> @endpoints.RosMessageType[Image] {
  @endpoints.RosMessageType::new(
    "sensor_msgs",
    "msg",
    "Image",
    Image_TYPE_HASH,
    fn(message) { Image::to_cdr_bytes(message) },
    Image::from_cdr_bytes,
  )
}

///|
/// Return the `sensor_msgs/msg/CompressedImage` wire identity and codecs.
pub fn CompressedImage::type_support() -> @endpoints.RosMessageType[
  CompressedImage,
] {
  @endpoints.RosMessageType::new(
    "sensor_msgs",
    "msg",
    "CompressedImage",
    CompressedImage_TYPE_HASH,
    fn(message) { CompressedImage::to_cdr_bytes(message) },
    CompressedImage::from_cdr_bytes,
  )
}

///|
/// Return the `sensor_msgs/msg/JointState` wire identity and codecs.
pub fn JointState::type_support() -> @endpoints.RosMessageType[JointState] {
  @endpoints.RosMessageType::new(
    "sensor_msgs",
    "msg",
    "JointState",
    JointState_TYPE_HASH,
    fn(message) { JointState::to_cdr_bytes(message) },
    JointState::from_cdr_bytes,
  )
}

///|
/// Return the `sensor_msgs/msg/PointField` wire identity and codecs.
pub fn PointField::type_support() -> @endpoints.RosMessageType[PointField] {
  @endpoints.RosMessageType::new(
    "sensor_msgs",
    "msg",
    "PointField",
    PointField_TYPE_HASH,
    fn(message) { PointField::to_cdr_bytes(message) },
    PointField::from_cdr_bytes,
  )
}

///|
/// Return the `sensor_msgs/msg/NavSatStatus` wire identity and codecs.
pub fn NavSatStatus::type_support() -> @endpoints.RosMessageType[NavSatStatus] {
  @endpoints.RosMessageType::new(
    "sensor_msgs",
    "msg",
    "NavSatStatus",
    NavSatStatus_TYPE_HASH,
    fn(message) { NavSatStatus::to_cdr_bytes(message) },
    NavSatStatus::from_cdr_bytes,
  )
}

///|
/// Return the `sensor_msgs/msg/RegionOfInterest` wire identity and codecs.
pub fn RegionOfInterest::type_support() -> @endpoints.RosMessageType[
  RegionOfInterest,
] {
  @endpoints.RosMessageType::new(
    "sensor_msgs",
    "msg",
    "RegionOfInterest",
    RegionOfInterest_TYPE_HASH,
    fn(message) { RegionOfInterest::to_cdr_bytes(message) },
    RegionOfInterest::from_cdr_bytes,
  )
}

///|
/// Return the `sensor_msgs/msg/CameraInfo` wire identity and codecs.
pub fn CameraInfo::type_support() -> @endpoints.RosMessageType[CameraInfo] {
  @endpoints.RosMessageType::new(
    "sensor_msgs",
    "msg",
    "CameraInfo",
    CameraInfo_TYPE_HASH,
    fn(message) { CameraInfo::to_cdr_bytes(message) },
    CameraInfo::from_cdr_bytes,
  )
}

///|
/// Return the `sensor_msgs/msg/PointCloud2` wire identity and codecs.
pub fn PointCloud2::type_support() -> @endpoints.RosMessageType[PointCloud2] {
  @endpoints.RosMessageType::new(
    "sensor_msgs",
    "msg",
    "PointCloud2",
    PointCloud2_TYPE_HASH,
    fn(message) { PointCloud2::to_cdr_bytes(message) },
    PointCloud2::from_cdr_bytes,
  )
}

///|
/// Return the `sensor_msgs/msg/NavSatFix` wire identity and codecs.
pub fn NavSatFix::type_support() -> @endpoints.RosMessageType[NavSatFix] {
  @endpoints.RosMessageType::new(
    "sensor_msgs",
    "msg",
    "NavSatFix",
    NavSatFix_TYPE_HASH,
    fn(message) { NavSatFix::to_cdr_bytes(message) },
    NavSatFix::from_cdr_bytes,
  )
}
