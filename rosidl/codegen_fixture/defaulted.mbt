///|
/// Generated from demo/msg/Defaulted.msg
pub struct Defaulted {
  enabled : Bool
  count : Int32
  label : String
  samples : Array[Int32]
  history : Array[Int32]
  zeros : Array[Int32]
} derive(Eq, Debug)

///|
pub extend Defaulted with Eq::{not_equal, equal}

///|
pub extend Defaulted with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Create a message with the defaulted fields.
pub fn Defaulted::new(
  enabled : Bool,
  count : Int32,
  label : String,
  samples : Array[Int32],
  history : Array[Int32],
  zeros : Array[Int32],
) -> Defaulted {
  { enabled, count, label, samples, history, zeros, }
}

///|
/// Create the message using its declared default values.
pub fn Defaulted::default() -> Defaulted {
  let enabled : Bool = true
  let count : Int32 = 42
  let label : String = "hello world"
  let samples : Array[Int32] = [1, 2, 3]
  let history : Array[Int32] = []
  let zeros : Array[Int32] = []
  for _ in 0..<2 {
    zeros.push(0)
  }
  Defaulted::new(enabled, count, label, samples, history, zeros)
}

///|
/// Return whether the message is enabled.
pub fn Defaulted::enabled(self : Defaulted) -> Bool {
  self.enabled
}

///|
/// Return the message count.
pub fn Defaulted::count(self : Defaulted) -> Int32 {
  self.count
}

///|
/// Return the message label.
pub fn Defaulted::label(self : Defaulted) -> String {
  self.label
}

///|
/// Return the message samples.
pub fn Defaulted::samples(self : Defaulted) -> Array[Int32] {
  self.samples
}

///|
/// Return the message history.
pub fn Defaulted::history(self : Defaulted) -> Array[Int32] {
  self.history
}

///|
/// Return the message zero values.
pub fn Defaulted::zeros(self : Defaulted) -> Array[Int32] {
  self.zeros
}
