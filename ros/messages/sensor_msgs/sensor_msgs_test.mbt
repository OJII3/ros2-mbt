///|
test "sensor_msgs message types CDR round trip" {
  let imu = @sensor_msgs.Imu::default()
  assert_eq(
    @sensor_msgs.Imu::from_cdr_bytes(imu.to_cdr_bytes().unwrap()).unwrap(),
    imu,
  )

  let scan = @sensor_msgs.LaserScan::default()
  assert_eq(
    @sensor_msgs.LaserScan::from_cdr_bytes(scan.to_cdr_bytes().unwrap()).unwrap(),
    scan,
  )

  let image = @sensor_msgs.Image::default()
  assert_eq(
    @sensor_msgs.Image::from_cdr_bytes(image.to_cdr_bytes().unwrap()).unwrap(),
    image,
  )

  let compressed_image = @sensor_msgs.CompressedImage::default()
  assert_eq(
    @sensor_msgs.CompressedImage::from_cdr_bytes(
      compressed_image.to_cdr_bytes().unwrap(),
    ).unwrap(),
    compressed_image,
  )

  let joint_state = @sensor_msgs.JointState::default()
  assert_eq(
    @sensor_msgs.JointState::from_cdr_bytes(joint_state.to_cdr_bytes().unwrap()).unwrap(),
    joint_state,
  )

  let point_field = @sensor_msgs.PointField::default()
  assert_eq(
    @sensor_msgs.PointField::from_cdr_bytes(point_field.to_cdr_bytes().unwrap()).unwrap(),
    point_field,
  )

  let nav_status = @sensor_msgs.NavSatStatus::default()
  assert_eq(
    @sensor_msgs.NavSatStatus::from_cdr_bytes(
      nav_status.to_cdr_bytes().unwrap(),
    ).unwrap(),
    nav_status,
  )

  let roi = @sensor_msgs.RegionOfInterest::default()
  assert_eq(
    @sensor_msgs.RegionOfInterest::from_cdr_bytes(roi.to_cdr_bytes().unwrap()).unwrap(),
    roi,
  )

  let camera_info = @sensor_msgs.CameraInfo::default()
  assert_eq(
    @sensor_msgs.CameraInfo::from_cdr_bytes(camera_info.to_cdr_bytes().unwrap()).unwrap(),
    camera_info,
  )

  let point_cloud = @sensor_msgs.PointCloud2::default()
  assert_eq(
    @sensor_msgs.PointCloud2::from_cdr_bytes(
      point_cloud.to_cdr_bytes().unwrap(),
    ).unwrap(),
    point_cloud,
  )

  let nav_fix = @sensor_msgs.NavSatFix::default()
  assert_eq(
    @sensor_msgs.NavSatFix::from_cdr_bytes(nav_fix.to_cdr_bytes().unwrap()).unwrap(),
    nav_fix,
  )
}

///|
test "sensor_msgs sequence fields CDR round trip" {
  let laser_scan = @sensor_msgs.LaserScan::new(
    @std.Header::default(),
    -1.0F,
    1.0F,
    0.25F,
    0.01F,
    0.1F,
    0.2F,
    10.0F,
    [0.5F, 1.5F],
    [3.0F, 4.0F],
  )
  assert_eq(
    @sensor_msgs.LaserScan::from_cdr_bytes(laser_scan.to_cdr_bytes().unwrap()).unwrap(),
    laser_scan,
  )

  let joint_state = @sensor_msgs.JointState::new(
    @std.Header::default(),
    ["joint_a", "joint_b"],
    [0.25, -0.5],
    [1.0, 1.5],
    [0.0, 2.0],
  )
  assert_eq(
    @sensor_msgs.JointState::from_cdr_bytes(joint_state.to_cdr_bytes().unwrap()).unwrap(),
    joint_state,
  )

  let image = @sensor_msgs.Image::new(
    @std.Header::default(),
    1U,
    2U,
    "rgb8",
    0,
    6U,
    [10, 20, 30, 40, 50, 60],
  )
  assert_eq(
    @sensor_msgs.Image::from_cdr_bytes(image.to_cdr_bytes().unwrap()).unwrap(),
    image,
  )

  let point_cloud = @sensor_msgs.PointCloud2::new(
    @std.Header::default(),
    1U,
    1U,
    [@sensor_msgs.PointField::new("x", 0U, @sensor_msgs.FLOAT32, 1U)],
    false,
    4U,
    4U,
    [0, 0, 128, 63],
    true,
  )
  assert_eq(
    @sensor_msgs.PointCloud2::from_cdr_bytes(
      point_cloud.to_cdr_bytes().unwrap(),
    ).unwrap(),
    point_cloud,
  )
}
