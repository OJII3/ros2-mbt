///|
fn builtin_geometry_msgs_message_source(type_name : String) -> String? {
  match type_name {
    "Point" => Some("float64 x\nfloat64 y\nfloat64 z\n")
    "Pose" => Some("Point position\nQuaternion orientation\n")
    "PoseStamped" => Some("std_msgs/Header header\nPose pose\n")
    "PoseWithCovariance" => Some("Pose pose\nfloat64[36] covariance\n")
    "Quaternion" => Some("float64 x 0\nfloat64 y 0\nfloat64 z 0\nfloat64 w 1\n")
    "Transform" => Some("Vector3 translation\nQuaternion rotation\n")
    "TransformStamped" =>
      Some(
        "std_msgs/Header header\nstring child_frame_id\nTransform transform\n",
      )
    "Twist" => Some("Vector3  linear\nVector3  angular\n")
    "TwistWithCovariance" => Some("Twist twist\nfloat64[36] covariance\n")
    "Vector3" => Some("float64 x\nfloat64 y\nfloat64 z\n")
    _ => None
  }
}
