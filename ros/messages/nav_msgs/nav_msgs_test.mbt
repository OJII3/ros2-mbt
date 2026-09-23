///|
test "nav_msgs message types CDR round trip" {
  let odometry = @nav_msgs.Odometry::default()
  assert_eq(
    @nav_msgs.Odometry::from_cdr_bytes(odometry.to_cdr_bytes().unwrap()).unwrap(),
    odometry,
  )

  let path = @nav_msgs.Path::default()
  assert_eq(
    @nav_msgs.Path::from_cdr_bytes(path.to_cdr_bytes().unwrap()).unwrap(),
    path,
  )

  let path_with_pose = @nav_msgs.Path::new(@std_msgs.Header::default(), [
    @geometry_msgs.PoseStamped::new(
      @std_msgs.Header::default(),
      @geometry_msgs.Pose::default(),
    ),
  ])
  assert_eq(
    @nav_msgs.Path::from_cdr_bytes(path_with_pose.to_cdr_bytes().unwrap()).unwrap(),
    path_with_pose,
  )

  let metadata = @nav_msgs.MapMetaData::default()
  assert_eq(
    @nav_msgs.MapMetaData::from_cdr_bytes(metadata.to_cdr_bytes().unwrap()).unwrap(),
    metadata,
  )

  let grid = @nav_msgs.OccupancyGrid::default()
  assert_eq(
    @nav_msgs.OccupancyGrid::from_cdr_bytes(grid.to_cdr_bytes().unwrap()).unwrap(),
    grid,
  )

  let grid_with_data = @nav_msgs.OccupancyGrid::new(
    @std_msgs.Header::default(),
    @nav_msgs.MapMetaData::default(),
    [-1, 0, 100],
  )
  assert_eq(
    @nav_msgs.OccupancyGrid::from_cdr_bytes(
      grid_with_data.to_cdr_bytes().unwrap(),
    ).unwrap(),
    grid_with_data,
  )
}
