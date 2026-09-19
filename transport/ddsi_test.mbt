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

///|
test "DDSI participant helper advertises standard locators" {
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let participant = match
    new_ddsi_participant(
      prefix,
      @rtps.VendorId::new(1, 15),
      0,
      3,
      0x7F000001U,
      60,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(participant.domain_id(), 0U)
  assert_eq(participant.lease_seconds(), 60)
  assert_eq(participant.builtin_endpoint_set(), 0x0000003FU)
  assert_eq(participant.metatraffic_unicast_locators().length(), 1)
  assert_eq(participant.metatraffic_multicast_locators().length(), 1)
  assert_eq(participant.default_unicast_locators().length(), 1)
  assert_eq(participant.default_multicast_locators().length(), 1)
  assert_eq(participant.metatraffic_unicast_locators()[0].port(), 7416)
  assert_eq(participant.default_unicast_locators()[0].port(), 7417)
  assert_eq(participant.metatraffic_multicast_locators()[0].port(), 7400)
  assert_eq(participant.default_multicast_locators()[0].port(), 7401)
}
