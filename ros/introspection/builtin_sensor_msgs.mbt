///|
fn builtin_sensor_msgs_message_source(type_name : String) -> String? {
  match type_name {
    "CameraInfo" =>
      Some(
        "std_msgs/Header header\nuint32 height\nuint32 width\nstring distortion_model\nfloat64[] d\nfloat64[9]  k\nfloat64[9]  r\nfloat64[12] p\nuint32 binning_x\nuint32 binning_y\nRegionOfInterest roi\n",
      )
    "CompressedImage" =>
      Some("std_msgs/Header header\nstring format\nuint8[] data\n")
    "Image" =>
      Some(
        "std_msgs/Header header\nuint32 height\nuint32 width\nstring encoding\nuint8 is_bigendian\nuint32 step\nuint8[] data\n",
      )
    "Imu" =>
      Some(
        "std_msgs/Header header\ngeometry_msgs/Quaternion orientation\nfloat64[9] orientation_covariance\ngeometry_msgs/Vector3 angular_velocity\nfloat64[9] angular_velocity_covariance\ngeometry_msgs/Vector3 linear_acceleration\nfloat64[9] linear_acceleration_covariance\n",
      )
    "JointState" =>
      Some(
        "std_msgs/Header header\nstring[] name\nfloat64[] position\nfloat64[] velocity\nfloat64[] effort\n",
      )
    "LaserScan" =>
      Some(
        "std_msgs/Header header\nfloat32 angle_min\nfloat32 angle_max\nfloat32 angle_increment\nfloat32 time_increment\nfloat32 scan_time\nfloat32 range_min\nfloat32 range_max\nfloat32[] ranges\nfloat32[] intensities\n",
      )
    "NavSatFix" =>
      Some(
        "std_msgs/Header header\nNavSatStatus status\nfloat64 latitude\nfloat64 longitude\nfloat64 altitude\nfloat64[9] position_covariance\nuint8 COVARIANCE_TYPE_UNKNOWN = 0\nuint8 COVARIANCE_TYPE_APPROXIMATED = 1\nuint8 COVARIANCE_TYPE_DIAGONAL_KNOWN = 2\nuint8 COVARIANCE_TYPE_KNOWN = 3\nuint8 position_covariance_type\n",
      )
    "NavSatStatus" =>
      Some(
        "int8 STATUS_UNKNOWN = -2\nint8 STATUS_NO_FIX =  -1\nint8 STATUS_FIX =      0\nint8 STATUS_SBAS_FIX = 1\nint8 STATUS_GBAS_FIX = 2\nint8 status -2\nuint16 SERVICE_UNKNOWN = 0\nuint16 SERVICE_GPS =     1\nuint16 SERVICE_GLONASS = 2\nuint16 SERVICE_COMPASS = 4\nuint16 SERVICE_GALILEO = 8\nuint16 service\n",
      )
    "PointCloud2" =>
      Some(
        "std_msgs/Header header\nuint32 height\nuint32 width\nPointField[] fields\nbool    is_bigendian\nuint32  point_step\nuint32  row_step\nuint8[] data\nbool is_dense\n",
      )
    "PointField" =>
      Some(
        "uint8 INT8    = 1\nuint8 UINT8   = 2\nuint8 INT16   = 3\nuint8 UINT16  = 4\nuint8 INT32   = 5\nuint8 UINT32  = 6\nuint8 FLOAT32 = 7\nuint8 FLOAT64 = 8\nstring name\nuint32 offset\nuint8  datatype\nuint32 count\n",
      )
    "RegionOfInterest" =>
      Some(
        "uint32 x_offset\nuint32 y_offset\nuint32 height\nuint32 width\nbool do_rectify\n",
      )
    _ => None
  }
}
