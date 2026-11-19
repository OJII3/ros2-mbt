///|
test "bench Odometry encode" (b : @bench.T) {
  let message = @nav_msgs.Odometry::default()
  b.bench(fn() { b.keep(message.to_cdr_bytes().unwrap()) })
}

///|
test "bench Odometry decode" (b : @bench.T) {
  let encoded = @nav_msgs.Odometry::default().to_cdr_bytes().unwrap()
  b.bench(fn() { b.keep(@nav_msgs.Odometry::from_cdr_bytes(encoded).unwrap()) })
}
