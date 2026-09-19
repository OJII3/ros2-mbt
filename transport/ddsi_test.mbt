///|
test "DDSI-RTPS default discovery ports" {
  assert_eq(ddsi_spdp_multicast_port(0), Ok(7400))
  assert_eq(ddsi_spdp_multicast_port(1), Ok(7650))
  assert_eq(ddsi_spdp_unicast_port(0, 3), Ok(7416))
  assert_eq(ddsi_spdp_unicast_port(2, 4), Ok(7918))
  assert_true(ddsi_spdp_multicast_port(1000) is Err(_))
}

///|
test "DDSI-RTPS default SPDP multicast address" {
  let address = match ddsi_default_spdp_multicast_addr(0) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(address.ip(), 0xEFFF0001U)
  assert_eq(address.port(), 7400)
}
