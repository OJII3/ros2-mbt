///|
struct HzStats {
  mut samples : Int32
  intervals : Array[Int64]
}

///|
fn add_sample(
  stats : HzStats,
  previous_sample_ms : Int64?,
  now_ms : Int64,
) -> Int64 {
  if previous_sample_ms is Some(previous) {
    stats.intervals.push(now_ms - previous)
  }
  stats.samples += 1
  now_ms
}

///|
priv struct HzSummary {
  average : Double
  min : Double
  max : Double
}

///|
fn summarize_hz_stats(stats : HzStats, duration_ms : Int32) -> HzSummary? {
  if stats.samples < 2 || stats.intervals.length() == 0 {
    return None
  }
  let total_interval_ms = stats.intervals.fold(init=0L, fn(total, interval) {
    total + interval
  })
  let min_interval_ms = stats.intervals.fold(init=stats.intervals[0], fn(
    earliest,
    interval,
  ) {
    earliest.min(interval)
  })
  let max_interval_ms = stats.intervals.fold(init=stats.intervals[0], fn(
    latest,
    interval,
  ) {
    latest.max(interval)
  })
  let elapsed_ms = if total_interval_ms > 0L {
    total_interval_ms
  } else {
    duration_ms.to_int64()
  }
  let average = stats.intervals.length().to_int64().to_double() /
    elapsed_ms.to_double() *
    1000.0
  Some({
    average,
    min: 1000.0 / max_interval_ms.to_double(),
    max: 1000.0 / min_interval_ms.to_double(),
  })
}
