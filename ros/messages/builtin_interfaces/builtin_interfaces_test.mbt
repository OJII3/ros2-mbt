///|
test "builtin_interfaces Time and Duration CDR round trip" {
  let time = @builtin_interfaces.Time::new(-12, 345678901U)
  assert_eq(
    @builtin_interfaces.Time::from_cdr_bytes(time.to_cdr_bytes().unwrap()).unwrap(),
    time,
  )

  let duration = @builtin_interfaces.Duration::new(9, 876543210U)
  assert_eq(
    @builtin_interfaces.Duration::from_cdr_bytes(
      duration.to_cdr_bytes().unwrap(),
    ).unwrap(),
    duration,
  )
}
