///|
test "bench Twist encode" (b : @bench.T) {
  let message = @geometry_msgs.Twist::new(
    @geometry_msgs.Vector3::new(1.5, -2.0, 3.25),
    @geometry_msgs.Vector3::new(-4.5, 5.0, 6.75),
  )
  b.bench(fn() { b.keep(message.to_cdr_bytes()) })
}

///|
test "bench Twist decode" (b : @bench.T) {
  let message = @geometry_msgs.Twist::new(
    @geometry_msgs.Vector3::new(1.5, -2.0, 3.25),
    @geometry_msgs.Vector3::new(-4.5, 5.0, 6.75),
  )
  let encoded = message.to_cdr_bytes()
  b.bench(fn() {
    b.keep(@geometry_msgs.Twist::from_cdr_bytes(encoded).unwrap())
  })
}

///|
test "bench PoseWithCovariance encode" (b : @bench.T) {
  let message = @geometry_msgs.PoseWithCovariance::default()
  b.bench(fn() { b.keep(message.to_cdr_bytes().unwrap()) })
}

///|
test "bench PoseWithCovariance decode" (b : @bench.T) {
  let encoded = @geometry_msgs.PoseWithCovariance::default()
    .to_cdr_bytes()
    .unwrap()
  b.bench(fn() {
    b.keep(@geometry_msgs.PoseWithCovariance::from_cdr_bytes(encoded).unwrap())
  })
}
