///|
test "RTPS QoS parameter helpers use CDR little-endian fields" {
  assert_eq(
    qos_reliability(RELIABILITY_RELIABLE, 0, 0).value(),
    b"\x02\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
  )
  assert_eq(
    qos_durability(DURABILITY_TRANSIENT_LOCAL).value(),
    b"\x01\x00\x00\x00",
  )
  assert_eq(
    qos_history(HISTORY_KEEP_LAST, 10).value(),
    b"\x00\x00\x00\x00\x0A\x00\x00\x00",
  )
  assert_eq(
    qos_liveliness(LIVELINESS_AUTOMATIC, 30, 0).value(),
    b"\x00\x00\x00\x00\x1E\x00\x00\x00\x00\x00\x00\x00",
  )
  assert_eq(
    qos_resource_limits(10, 1, 10).value(),
    b"\x0A\x00\x00\x00\x01\x00\x00\x00\x0A\x00\x00\x00",
  )
}

///|
test "RTPS QoS durations encode nanoseconds as NTP fractions" {
  assert_eq(
    qos_deadline(3, 500_000_000U).value(),
    b"\x03\x00\x00\x00\x00\x00\x00\x80",
  )
  assert_eq(
    qos_deadline(0, 2U).value(),
    b"\x00\x00\x00\x00\x09\x00\x00\x00",
  )
}

///|
test "RTPS QoS helper parameter identifiers" {
  assert_eq(qos_deadline(1, 2).id(), PID_DEADLINE)
  assert_eq(qos_lifespan(1, 2).id(), PID_LIFESPAN)
  assert_eq(qos_latency_budget(1, 2).id(), 0x0027)
  assert_eq(qos_ownership(OWNERSHIP_SHARED).id(), PID_OWNERSHIP)
  assert_eq(
    qos_destination_order(DESTINATION_ORDER_BY_RECEPTION_TIMESTAMP).id(),
    PID_DESTINATION_ORDER,
  )
  assert_eq(qos_expects_inline_qos(false).value(), b"\x00\x00\x00\x00")
  assert_eq(
    qos_data_representation([0, 2]).value(),
    b"\x02\x00\x00\x00\x00\x00\x02\x00",
  )
  assert_eq(qos_type_max_size_serialized(1024).value(), b"\x00\x04\x00\x00")
}

///|
test "RTPS QoS helper encodes ROS type hash user data" {
  let type_hash =
    "RIHS01_df668c740482bbd48fb39d76a70dfd4bd59db1288021743503259e948f6b1a18"
  let parameter = qos_user_data_type_hash(type_hash)
  assert_eq(parameter.id(), PID_USER_DATA)
  assert_eq(parameter.value(), @utf8.encode("typehash=" + type_hash + ";"))
}
