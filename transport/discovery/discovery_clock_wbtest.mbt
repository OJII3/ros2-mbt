///|
test "discovery clock returns nonnegative nondecreasing milliseconds" {
  let clock = DiscoveryClock::new()
  let mut previous = clock.now_ms()
  assert_true(previous >= 0L)
  for _ in 0..<100 {
    let current = clock.now_ms()
    assert_true(current >= previous)
    previous = current
  }
}

///|
async test "discovery clock uses session-relative milliseconds" {
  let before = @bench.monotonic_clock_start()
  let clock = DiscoveryClock::new()
  let after = @bench.monotonic_clock_start()
  @async.sleep(20)
  let lower = (@bench.monotonic_clock_end(after) / 1000.0).to_int64()
  let elapsed = clock.now_ms()
  let upper = (@bench.monotonic_clock_end(before) / 1000.0).to_int64()
  assert_true(elapsed >= lower)
  assert_true(elapsed <= upper)
  let fresh = DiscoveryClock::new()
  assert_true(fresh.now_ms() <= clock.now_ms() - lower)
}
