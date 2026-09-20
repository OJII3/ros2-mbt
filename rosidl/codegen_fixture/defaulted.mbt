///|
/// Generated from demo/msg/Defaulted.msg
pub struct Defaulted {
  enabled : Bool
  count : Int
  label : String
  samples : Array[Int]
  history : Array[Int]
  zeros : Array[Int]
} derive(Eq, Debug)

///|
pub fn Defaulted::new(
  enabled : Bool,
  count : Int,
  label : String,
  samples : Array[Int],
  history : Array[Int],
  zeros : Array[Int],
) -> Defaulted {
  { enabled, count, label, samples, history, zeros, }
}

///|
pub fn Defaulted::default() -> Defaulted {
  let enabled : Bool = true
  let count : Int = 42
  let label : String = "hello world"
  let samples : Array[Int] = [1, 2, 3]
  let history : Array[Int] = []
  let zeros : Array[Int] = []
  for _ in 0..<2 {
    zeros.push(0)
  }
  Defaulted::new(enabled, count, label, samples, history, zeros)
}

///|
pub fn Defaulted::enabled(self : Defaulted) -> Bool {
  self.enabled
}

///|
pub fn Defaulted::count(self : Defaulted) -> Int {
  self.count
}

///|
pub fn Defaulted::label(self : Defaulted) -> String {
  self.label
}

///|
pub fn Defaulted::samples(self : Defaulted) -> Array[Int] {
  self.samples
}

///|
pub fn Defaulted::history(self : Defaulted) -> Array[Int] {
  self.history
}

///|
pub fn Defaulted::zeros(self : Defaulted) -> Array[Int] {
  self.zeros
}
