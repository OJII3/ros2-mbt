///|

///|
/// Return the `geometry_msgs/msg/Vector3` wire identity and codecs.
pub fn Vector3::type_support() -> @endpoints.RosMessageType[Vector3] {
  @endpoints.RosMessageType::new(
    "geometry_msgs",
    "msg",
    "Vector3",
    Vector3_TYPE_HASH,
    fn(message) { Ok(Vector3::to_cdr_bytes(message)) },
    Vector3::from_cdr_bytes,
  )
}

///|
/// Return the `geometry_msgs/msg/Twist` wire identity and codecs.
pub fn Twist::type_support() -> @endpoints.RosMessageType[Twist] {
  @endpoints.RosMessageType::new(
    "geometry_msgs",
    "msg",
    "Twist",
    Twist_TYPE_HASH,
    fn(message) { Ok(Twist::to_cdr_bytes(message)) },
    Twist::from_cdr_bytes,
  )
}

///|
/// Return the `geometry_msgs/msg/Point` wire identity and codecs.
pub fn Point::type_support() -> @endpoints.RosMessageType[Point] {
  @endpoints.RosMessageType::new(
    "geometry_msgs",
    "msg",
    "Point",
    Point_TYPE_HASH,
    fn(message) { Point::to_cdr_bytes(message) },
    Point::from_cdr_bytes,
  )
}

///|
/// Return the `geometry_msgs/msg/Quaternion` wire identity and codecs.
pub fn Quaternion::type_support() -> @endpoints.RosMessageType[Quaternion] {
  @endpoints.RosMessageType::new(
    "geometry_msgs",
    "msg",
    "Quaternion",
    Quaternion_TYPE_HASH,
    fn(message) { Quaternion::to_cdr_bytes(message) },
    Quaternion::from_cdr_bytes,
  )
}

///|
/// Return the `geometry_msgs/msg/Pose` wire identity and codecs.
pub fn Pose::type_support() -> @endpoints.RosMessageType[Pose] {
  @endpoints.RosMessageType::new(
    "geometry_msgs",
    "msg",
    "Pose",
    Pose_TYPE_HASH,
    fn(message) { Pose::to_cdr_bytes(message) },
    Pose::from_cdr_bytes,
  )
}

///|
/// Return the `geometry_msgs/msg/Transform` wire identity and codecs.
pub fn Transform::type_support() -> @endpoints.RosMessageType[Transform] {
  @endpoints.RosMessageType::new(
    "geometry_msgs",
    "msg",
    "Transform",
    Transform_TYPE_HASH,
    fn(message) { Transform::to_cdr_bytes(message) },
    Transform::from_cdr_bytes,
  )
}

///|
/// Return the `geometry_msgs/msg/TransformStamped` wire identity and codecs.
pub fn TransformStamped::type_support() -> @endpoints.RosMessageType[
  TransformStamped,
] {
  @endpoints.RosMessageType::new(
    "geometry_msgs",
    "msg",
    "TransformStamped",
    TransformStamped_TYPE_HASH,
    fn(message) { TransformStamped::to_cdr_bytes(message) },
    TransformStamped::from_cdr_bytes,
  )
}

///|
/// Return the `geometry_msgs/msg/PoseStamped` wire identity and codecs.
pub fn PoseStamped::type_support() -> @endpoints.RosMessageType[PoseStamped] {
  @endpoints.RosMessageType::new(
    "geometry_msgs",
    "msg",
    "PoseStamped",
    PoseStamped_TYPE_HASH,
    fn(message) { PoseStamped::to_cdr_bytes(message) },
    PoseStamped::from_cdr_bytes,
  )
}

///|
/// Return the `geometry_msgs/msg/PoseWithCovariance` wire identity and codecs.
pub fn PoseWithCovariance::type_support() -> @endpoints.RosMessageType[
  PoseWithCovariance,
] {
  @endpoints.RosMessageType::new(
    "geometry_msgs",
    "msg",
    "PoseWithCovariance",
    PoseWithCovariance_TYPE_HASH,
    fn(message) { PoseWithCovariance::to_cdr_bytes(message) },
    PoseWithCovariance::from_cdr_bytes,
  )
}

///|
/// Return the `geometry_msgs/msg/TwistWithCovariance` wire identity and codecs.
pub fn TwistWithCovariance::type_support() -> @endpoints.RosMessageType[
  TwistWithCovariance,
] {
  @endpoints.RosMessageType::new(
    "geometry_msgs",
    "msg",
    "TwistWithCovariance",
    TwistWithCovariance_TYPE_HASH,
    fn(message) { TwistWithCovariance::to_cdr_bytes(message) },
    TwistWithCovariance::from_cdr_bytes,
  )
}
