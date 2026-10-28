///|
/// Monotonic milliseconds relative to this discovery session's start.
struct DiscoveryClock {
  start : @bench.Timestamp
}

///|
fn DiscoveryClock::new() -> DiscoveryClock {
  { start: @bench.monotonic_clock_start(), }
}

///|
fn DiscoveryClock::now_ms(self : DiscoveryClock) -> Int64 {
  // bench returns microseconds; discard fractional milliseconds.
  (@bench.monotonic_clock_end(self.start) / 1000.0).to_int64()
}
