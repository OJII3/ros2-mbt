///|
test "hz statistics use intervals between samples" {
  let stats : HzStats = { samples: 0, intervals: [], }
  let first = add_sample(stats, None, 1000L)
  let second = add_sample(stats, Some(first), 1100L)
  ignore(add_sample(stats, Some(second), 1300L))
  assert_eq(stats.samples, 3)
  assert_eq(stats.intervals, [100L, 200L])
  guard summarize_hz_stats(stats, 5000) is Some(summary) else {
    fail("expected a summary")
  }
  assert_eq(summary.average, 2.0 / 300.0 * 1000.0)
  assert_eq(summary.min, 5.0)
  assert_eq(summary.max, 10.0)
}

///|
test "hz statistics require two samples" {
  let stats : HzStats = { samples: 0, intervals: [], }
  assert_true(summarize_hz_stats(stats, 1000) is None)
  ignore(add_sample(stats, None, 100L))
  assert_true(summarize_hz_stats(stats, 1000) is None)
}

///|
test "hz statistics fall back to measurement duration for simultaneous samples" {
  let stats : HzStats = { samples: 2, intervals: [0L], }
  guard summarize_hz_stats(stats, 2000) is Some(summary) else {
    fail("expected a summary")
  }
  assert_eq(summary.average, 0.5)
  assert_true(summary.min > 1.0e300)
  assert_true(summary.max > 1.0e300)
}

///|
async test "hz collection ignores timeouts and bounds polling by the deadline" {
  let mut clock = 1000L
  let timeouts : Array[Int32] = []
  let stats = collect_hz_stats(250, fn() { clock }, fn(timeout_ms) {
    timeouts.push(timeout_ms)
    clock += timeout_ms.to_int64()
    Ok(timeouts.length() != 2)
  })
  guard stats is Ok(stats) else { fail("expected successful measurement") }
  assert_eq(timeouts, [100, 100, 50])
  assert_eq(stats.samples, 2)
  assert_eq(stats.intervals, [150L])
}

///|
async test "hz collection stops immediately on receive failure" {
  let mut calls = 0
  let result = collect_hz_stats(1000, fn() { 0L }, fn(_timeout_ms) {
    calls += 1
    Err("receive failed")
  })
  assert_true(result is Err("receive failed"))
  assert_eq(calls, 1)
}

///|
async test "hz collection does not receive after an elapsed deadline" {
  let mut calls = 0
  let result = collect_hz_stats(0, fn() { 0L }, fn(_timeout_ms) {
    calls += 1
    Ok(true)
  })
  guard result is Ok(stats) else { fail("expected successful measurement") }
  assert_eq(stats.samples, 0)
  assert_eq(calls, 0)
}
