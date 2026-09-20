///|
/// DDS reliability kind values used by PID_RELIABILITY.
pub const RELIABILITY_BEST_EFFORT : UInt = 1

///|
pub const RELIABILITY_RELIABLE : UInt = 2

///|
/// DDS durability kind values used by PID_DURABILITY.
pub const DURABILITY_VOLATILE : UInt = 0

///|
pub const DURABILITY_TRANSIENT_LOCAL : UInt = 1

///|
pub const DURABILITY_TRANSIENT : UInt = 2

///|
pub const DURABILITY_PERSISTENT : UInt = 3

///|
/// DDS history kind values used by PID_HISTORY.
pub const HISTORY_KEEP_LAST : UInt = 0

///|
pub const HISTORY_KEEP_ALL : UInt = 1

///|
/// DDS liveliness kind values used by PID_LIVELINESS.
pub const LIVELINESS_AUTOMATIC : UInt = 0

///|
pub const LIVELINESS_MANUAL_BY_PARTICIPANT : UInt = 1

///|
pub const LIVELINESS_MANUAL_BY_TOPIC : UInt = 2

///|
/// DDS ownership kind values used by PID_OWNERSHIP.
pub const OWNERSHIP_SHARED : UInt = 0

///|
pub const OWNERSHIP_EXCLUSIVE : UInt = 1

///|
/// DDS destination-order kind values used by PID_DESTINATION_ORDER.
pub const DESTINATION_ORDER_BY_RECEPTION_TIMESTAMP : UInt = 0

///|
pub const DESTINATION_ORDER_BY_SOURCE_TIMESTAMP : UInt = 1

///|
/// DDS XCDR1 data-representation identifier.
pub const DATA_REPRESENTATION_XCDR1 : UInt16 = 0

///|
/// DDS XCDR2 data-representation identifier.
pub const DATA_REPRESENTATION_XCDR2 : UInt16 = 2

///|
fn qos_u32_le(value : UInt) -> Bytes {
  Bytes::from_array([
    value.to_byte(),
    (value >> 8).to_byte(),
    (value >> 16).to_byte(),
    (value >> 24).to_byte(),
  ])
}

///|
fn qos_i32_le(value : Int) -> Bytes {
  qos_u32_le(value.reinterpret_as_uint())
}

///|
fn qos_fraction_to_nanoseconds(fraction : UInt) -> UInt {
  ((fraction.to_uint64() * 1_000_000_000U.to_uint64()) >> 32).to_uint()
}

///|
fn qos_nanoseconds_to_fraction(nanoseconds : UInt) -> UInt {
  if nanoseconds >= 1_000_000_000U {
    return 0xFFFFFFFFU
  }
  let mut fraction = (
    nanoseconds.to_uint64() * (1U.to_uint64() << 32) /
    1_000_000_000U.to_uint64()
  ).to_uint()
  while qos_fraction_to_nanoseconds(fraction) < nanoseconds {
    fraction += 1U
  }
  fraction
}

///|
fn qos_duration(seconds : Int, nanoseconds : UInt) -> Bytes {
  let bytes : Array[Byte] = []
  let seconds_bytes = qos_i32_le(seconds)
  let fraction_bytes = qos_u32_le(qos_nanoseconds_to_fraction(nanoseconds))
  for i in 0..<4 {
    bytes.push(seconds_bytes[i])
  }
  for i in 0..<4 {
    bytes.push(fraction_bytes[i])
  }
  Bytes::from_array(bytes)
}

///|
fn qos_kind(kind : UInt) -> Bytes {
  qos_u32_le(kind)
}

///|
/// Construct a PID_RELIABILITY parameter.
pub fn qos_reliability(
  kind : UInt,
  max_blocking_seconds : Int,
  max_blocking_nanoseconds : UInt,
) -> Parameter {
  let bytes : Array[Byte] = []
  let kind_bytes = qos_kind(kind)
  let duration_bytes = qos_duration(
    max_blocking_seconds, max_blocking_nanoseconds,
  )
  for i in 0..<4 {
    bytes.push(kind_bytes[i])
  }
  for i in 0..<8 {
    bytes.push(duration_bytes[i])
  }
  Parameter::new(PID_RELIABILITY, Bytes::from_array(bytes))
}

///|
/// Construct a PID_DURABILITY parameter.
pub fn qos_durability(kind : UInt) -> Parameter {
  Parameter::new(PID_DURABILITY, qos_kind(kind))
}

///|
/// Construct a PID_HISTORY parameter.
pub fn qos_history(kind : UInt, depth : Int) -> Parameter {
  let bytes : Array[Byte] = []
  let kind_bytes = qos_kind(kind)
  let depth_bytes = qos_i32_le(depth)
  for i in 0..<4 {
    bytes.push(kind_bytes[i])
  }
  for i in 0..<4 {
    bytes.push(depth_bytes[i])
  }
  Parameter::new(PID_HISTORY, Bytes::from_array(bytes))
}

///|
/// Construct a duration-valued QoS parameter.
pub fn qos_deadline(seconds : Int, nanoseconds : UInt) -> Parameter {
  qos_deadline_fraction(seconds, qos_nanoseconds_to_fraction(nanoseconds))
}

///|
fn qos_deadline_fraction(seconds : Int, fraction : UInt) -> Parameter {
  let bytes : Array[Byte] = []
  let seconds_bytes = qos_i32_le(seconds)
  let fraction_bytes = qos_u32_le(fraction)
  for i in 0..<4 {
    bytes.push(seconds_bytes[i])
  }
  for i in 0..<4 {
    bytes.push(fraction_bytes[i])
  }
  Parameter::new(PID_DEADLINE, Bytes::from_array(bytes))
}

///|
/// Construct a PID_LIFESPAN parameter.
pub fn qos_lifespan(seconds : Int, nanoseconds : UInt) -> Parameter {
  Parameter::new(PID_LIFESPAN, qos_duration(seconds, nanoseconds))
}

///|
/// Construct a PID_USER_DATA parameter without interpreting its opaque bytes.
pub fn qos_user_data(value : Bytes) -> Parameter {
  Parameter::new(PID_USER_DATA, value)
}

///|
/// Construct ROS 2's `typehash=<RIHS01 hash>;` USER_DATA value.
pub fn qos_user_data_type_hash(type_hash : String) -> Parameter {
  qos_user_data(@utf8.encode("typehash=" + type_hash + ";"))
}

///|
/// Construct a PID_LATENCY_BUDGET parameter.
pub fn qos_latency_budget(seconds : Int, nanoseconds : UInt) -> Parameter {
  Parameter::new(PID_LATENCY_BUDGET, qos_duration(seconds, nanoseconds))
}

///|
/// Construct a PID_LIVELINESS parameter.
pub fn qos_liveliness(
  kind : UInt,
  lease_seconds : Int,
  lease_nanoseconds : UInt,
) -> Parameter {
  qos_liveliness_fraction(
    kind,
    lease_seconds,
    qos_nanoseconds_to_fraction(lease_nanoseconds),
  )
}

///|
fn qos_liveliness_fraction(
  kind : UInt,
  lease_seconds : Int,
  lease_fraction : UInt,
) -> Parameter {
  let bytes : Array[Byte] = []
  let kind_bytes = qos_kind(kind)
  let seconds_bytes = qos_i32_le(lease_seconds)
  let fraction_bytes = qos_u32_le(lease_fraction)
  for i in 0..<4 {
    bytes.push(kind_bytes[i])
  }
  for i in 0..<4 {
    bytes.push(seconds_bytes[i])
  }
  for i in 0..<4 {
    bytes.push(fraction_bytes[i])
  }
  Parameter::new(PID_LIVELINESS, Bytes::from_array(bytes))
}

///|
/// Construct a PID_OWNERSHIP parameter.
pub fn qos_ownership(kind : UInt) -> Parameter {
  Parameter::new(PID_OWNERSHIP, qos_kind(kind))
}

///|
/// Construct a PID_OWNERSHIP_STRENGTH parameter.
pub fn qos_ownership_strength(value : Int) -> Parameter {
  Parameter::new(PID_OWNERSHIP_STRENGTH, qos_i32_le(value))
}

///|
/// Construct a PID_DESTINATION_ORDER parameter.
pub fn qos_destination_order(kind : UInt) -> Parameter {
  Parameter::new(PID_DESTINATION_ORDER, qos_kind(kind))
}

///|
/// Construct a PID_RESOURCE_LIMITS parameter.
pub fn qos_resource_limits(
  max_samples : Int,
  max_instances : Int,
  max_samples_per_instance : Int,
) -> Parameter {
  let bytes : Array[Byte] = []
  let values = [max_samples, max_instances, max_samples_per_instance]
  for value in values {
    let encoded = qos_i32_le(value)
    for i in 0..<4 {
      bytes.push(encoded[i])
    }
  }
  Parameter::new(PID_RESOURCE_LIMITS, Bytes::from_array(bytes))
}

///|
/// Construct the four-byte CDR boolean PID_EXPECTS_INLINE_QOS parameter.
pub fn qos_expects_inline_qos(value : Bool) -> Parameter {
  Parameter::new(
    PID_EXPECTS_INLINE_QOS,
    if value {
      b"\x01\x00\x00\x00"
    } else {
      b"\x00\x00\x00\x00"
    },
  )
}

///|
/// Construct a PID_DATA_REPRESENTATION sequence parameter.
pub fn qos_data_representation(representations : Array[UInt16]) -> Parameter {
  let bytes : Array[Byte] = []
  let length = representations.length().reinterpret_as_uint()
  let length_bytes = qos_u32_le(length)
  for i in 0..<4 {
    bytes.push(length_bytes[i])
  }
  for representation in representations {
    bytes.push(representation.to_byte())
    bytes.push((representation.to_int() >> 8).to_byte())
  }
  Parameter::new(PID_DATA_REPRESENTATION, Bytes::from_array(bytes))
}

///|
/// Construct a PID_TYPE_MAX_SIZE_SERIALIZED parameter.
pub fn qos_type_max_size_serialized(value : UInt) -> Parameter {
  Parameter::new(PID_TYPE_MAX_SIZE_SERIALIZED, qos_u32_le(value))
}
