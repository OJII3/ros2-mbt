///|
test "DDSI-RTPS default discovery ports" {
  assert_eq(ddsi_spdp_multicast_port(0), Ok(7400))
  assert_eq(ddsi_spdp_multicast_port(1), Ok(7650))
  assert_eq(ddsi_spdp_unicast_port(0, 3), Ok(7416))
  assert_eq(ddsi_spdp_unicast_port(2, 4), Ok(7918))
  assert_eq(ddsi_user_multicast_port(0), Ok(7401))
  assert_eq(ddsi_user_unicast_port(0, 0), Ok(7411))
  assert_eq(ddsi_user_unicast_port(3, 2), Ok(8165))
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

///|
test "DDSI-RTPS default IPv4 addresses" {
  let spdp = match ddsi_default_spdp_unicast_addr(0, 0, 0x7F000001U) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let user = match ddsi_default_user_unicast_addr(0, 0, 0x7F000001U) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let multicast = match ddsi_default_user_multicast_addr(0) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(spdp.ip(), 0x7F000001U)
  assert_eq(spdp.port(), 7410)
  assert_eq(user.ip(), 0x7F000001U)
  assert_eq(user.port(), 7411)
  assert_eq(multicast.ip(), 0xEFFF0001U)
  assert_eq(multicast.port(), 7401)
}
