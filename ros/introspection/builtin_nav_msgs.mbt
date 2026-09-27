///|
fn builtin_nav_msgs_message_source(type_name : String) -> String? {
  match type_name {
    "MapMetaData" =>
      Some(
        "builtin_interfaces/Time map_load_time\nfloat32 resolution\nuint32 width\nuint32 height\ngeometry_msgs/Pose origin\n",
      )
    "OccupancyGrid" =>
      Some("std_msgs/Header header\nMapMetaData info\nint8[] data\n")
    "Odometry" =>
      Some(
        "std_msgs/Header header\nstring child_frame_id\ngeometry_msgs/PoseWithCovariance pose\ngeometry_msgs/TwistWithCovariance twist\n",
      )
    "Path" =>
      Some("std_msgs/Header header\ngeometry_msgs/PoseStamped[] poses\n")
    _ => None
  }
}
