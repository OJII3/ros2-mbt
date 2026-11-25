///|
#proof_pure
fn padding_bytes_length(bytes : Bytes) -> Int32 {
  bytes.length()
}

///|
/// Return whether every byte in `bytes` from `start` up to `stop` is zero.
///
/// `cdr` uses this for the zero-filled tail padding of an aggregate. The
/// predicate `zero_filled` is the logic-side specification proved by
/// `moon prove`.
pub fn is_zero_filled(
  bytes : Bytes,
  start : Int32,
  stop : Int32,
) -> Bool where {
  proof_require: 0 <= start,
  proof_require: start <= stop,
  proof_require: stop <= padding_bytes_length(bytes),
  proof_ensure: result => result == zero_filled(bytes, start, stop),
} {
  for index = start, filled = true; index < stop; {
    continue index + 1, filled && bytes[index] == 0
  } nobreak {
    filled
  } where {
    proof_invariant: start <= index,
    proof_invariant: index <= stop,
    proof_invariant: filled == zero_filled(bytes, start, index),
    proof_reasoning: (
      #| The processed prefix is `bytes[start .. index)`. `filled` records
      #| whether every byte in that prefix is zero, so the invariant starts
      #| with `filled = true` at `index = start`.
      #|
      #| Each step extends the prefix by one byte and conjoins
      #| `bytes[index] == 0` into `filled`. When the loop exits, `index == stop`
      #| and the invariant is exactly `zero_filled(bytes, start, stop)`.
      #|
      #| `index` increases by one on every iteration, so `stop - index` is a
      #| decreasing termination measure.
    ),
  }
}
