///|
fn bench_image(width : UInt32, height : UInt32) -> @sensor_msgs.Image {
  let data = Array::make((width * height * 3U).reinterpret_as_int(), b'\x7F')
  @sensor_msgs.Image::new(
    @std.Header::default(),
    height,
    width,
    "rgb8",
    0,
    width * 3U,
    data,
  )
}

///|
test "bench Image 1280x720 encode" (b : @bench.T) {
  let image = bench_image(1280U, 720U)
  b.bench(fn() { b.keep(image.to_cdr_bytes().unwrap()) })
}

///|
test "bench Image 1280x720 decode" (b : @bench.T) {
  let encoded = bench_image(1280U, 720U).to_cdr_bytes().unwrap()
  b.bench(fn() { b.keep(@sensor_msgs.Image::from_cdr_bytes(encoded).unwrap()) })
}

///|
test "bench PointCloud2 1 MiB encode" (b : @bench.T) {
  let data = Array::make(1024 * 1024, b'\x01')
  let cloud = @sensor_msgs.PointCloud2::new(
    @std.Header::default(),
    1U,
    (1024 * 1024 / 16).reinterpret_as_uint(),
    [
      @sensor_msgs.PointField::new("x", 0U, 7, 1U),
      @sensor_msgs.PointField::new("y", 4U, 7, 1U),
      @sensor_msgs.PointField::new("z", 8U, 7, 1U),
      @sensor_msgs.PointField::new("intensity", 12U, 7, 1U),
    ],
    false,
    16U,
    (1024 * 1024).reinterpret_as_uint(),
    data,
    true,
  )
  b.bench(fn() { b.keep(cloud.to_cdr_bytes().unwrap()) })
}

///|
test "bench PointCloud2 1 MiB decode" (b : @bench.T) {
  let data = Array::make(1024 * 1024, b'\x01')
  let cloud = @sensor_msgs.PointCloud2::new(
    @std.Header::default(),
    1U,
    (1024 * 1024 / 16).reinterpret_as_uint(),
    [
      @sensor_msgs.PointField::new("x", 0U, 7, 1U),
      @sensor_msgs.PointField::new("y", 4U, 7, 1U),
      @sensor_msgs.PointField::new("z", 8U, 7, 1U),
      @sensor_msgs.PointField::new("intensity", 12U, 7, 1U),
    ],
    false,
    16U,
    (1024 * 1024).reinterpret_as_uint(),
    data,
    true,
  )
  let encoded = cloud.to_cdr_bytes().unwrap()
  b.bench(fn() {
    b.keep(@sensor_msgs.PointCloud2::from_cdr_bytes(encoded).unwrap())
  })
}

///|
test "bench Imu encode" (b : @bench.T) {
  let message = @sensor_msgs.Imu::default()
  b.bench(fn() { b.keep(message.to_cdr_bytes().unwrap()) })
}

///|
test "bench Imu decode" (b : @bench.T) {
  let encoded = @sensor_msgs.Imu::default().to_cdr_bytes().unwrap()
  b.bench(fn() { b.keep(@sensor_msgs.Imu::from_cdr_bytes(encoded).unwrap()) })
}

///|
test "bench LaserScan encode" (b : @bench.T) {
  let message = @sensor_msgs.LaserScan::default()
  b.bench(fn() { b.keep(message.to_cdr_bytes().unwrap()) })
}

///|
test "bench LaserScan decode" (b : @bench.T) {
  let encoded = @sensor_msgs.LaserScan::default().to_cdr_bytes().unwrap()
  b.bench(fn() {
    b.keep(@sensor_msgs.LaserScan::from_cdr_bytes(encoded).unwrap())
  })
}

///|
fn bench_laser_scan() -> @sensor_msgs.LaserScan {
  let ranges = Array::make(1080, 1.25F)
  let intensities = Array::make(1080, 0.5F)
  @sensor_msgs.LaserScan::new(
    @std.Header::default(),
    -3.14F,
    3.14F,
    0.0058F,
    0.0F,
    0.1F,
    0.05F,
    12.0F,
    ranges,
    intensities,
  )
}

///|
test "bench LaserScan 1080 ranges encode" (b : @bench.T) {
  let message = bench_laser_scan()
  b.bench(fn() { b.keep(message.to_cdr_bytes().unwrap()) })
}

///|
test "bench LaserScan 1080 ranges decode" (b : @bench.T) {
  let encoded = bench_laser_scan().to_cdr_bytes().unwrap()
  b.bench(fn() {
    b.keep(@sensor_msgs.LaserScan::from_cdr_bytes(encoded).unwrap())
  })
}

///|
test "bench JointState 12 joints encode" (b : @bench.T) {
  let values = Array::make(12, 0.25)
  let message = @sensor_msgs.JointState::new(
    @std.Header::default(),
    Array::make(12, "joint"),
    values,
    values,
    values,
  )
  b.bench(fn() { b.keep(message.to_cdr_bytes().unwrap()) })
}

///|
test "bench JointState 12 joints decode" (b : @bench.T) {
  let values = Array::make(12, 0.25)
  let message = @sensor_msgs.JointState::new(
    @std.Header::default(),
    Array::make(12, "joint"),
    values,
    values,
    values,
  )
  let encoded = message.to_cdr_bytes().unwrap()
  b.bench(fn() {
    b.keep(@sensor_msgs.JointState::from_cdr_bytes(encoded).unwrap())
  })
}
