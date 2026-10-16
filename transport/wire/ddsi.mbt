///|
/// DDSI-RTPS default port base.
pub const DDSI_PORT_BASE : Int32 = 7400

///|
/// DDSI-RTPS port gain between domain IDs.
pub const DDSI_DOMAIN_ID_GAIN : Int32 = 250

///|
/// DDSI-RTPS port gain between participant IDs.
pub const DDSI_PARTICIPANT_ID_GAIN : Int32 = 2

///|
/// DDSI-RTPS SPDP multicast port offset.
pub const DDSI_SPDP_MULTICAST_OFFSET : Int32 = 0

///|
/// DDSI-RTPS SPDP unicast port offset.
pub const DDSI_SPDP_UNICAST_OFFSET : Int32 = 10

///|
/// Default DDSI-RTPS IPv4 multicast address, 239.255.0.1.
pub const DDSI_DEFAULT_MULTICAST_IP : UInt32 = 0xEFFF0001

///|
/// DDSI-RTPS user-data multicast port offset.
pub const DDSI_USER_MULTICAST_OFFSET : Int32 = 1

///|
/// DDSI-RTPS user-data unicast port offset.
pub const DDSI_USER_UNICAST_OFFSET : Int32 = 11

///|
/// Convert an IPv4 integer and port into an RTPS UDP locator.
fn ddsi_udp_locator(ip : UInt32, port : Int32) -> Result[@rtps.Locator, String] {
  @rtps.Locator::udp_v4(
    Bytes::from_array([
      (ip >> 24).to_byte(),
      (ip >> 16).to_byte(),
      (ip >> 8).to_byte(),
      ip.to_byte(),
    ]),
    port.reinterpret_as_uint(),
  )
}

///|
fn ddsi_port(domain_id : UInt32, offset : Int32) -> Result[Int32, String] {
  let domain = domain_id.reinterpret_as_int()
  if domain < 0 || offset < 0 {
    return Err("the DDSI-RTPS domain or participant ID is out of range")
  }
  let port = DDSI_PORT_BASE + domain * DDSI_DOMAIN_ID_GAIN + offset
  if port < 1 || port > 65535 {
    return Err("the DDSI-RTPS port is outside the UDP port range")
  }
  Ok(port)
}

///|
/// Return the default SPDP multicast port for a DDS domain.
pub fn ddsi_spdp_multicast_port(domain_id : UInt32) -> Result[Int32, String] {
  ddsi_port(domain_id, DDSI_SPDP_MULTICAST_OFFSET)
}

///|
/// Return the default SPDP unicast port for a domain and participant ID.
pub fn ddsi_spdp_unicast_port(
  domain_id : UInt32,
  participant_id : UInt32,
) -> Result[Int32, String] {
  let participant = participant_id.reinterpret_as_int()
  if participant < 0 {
    return Err("the DDSI-RTPS participant ID is out of range")
  }
  ddsi_port(
    domain_id,
    DDSI_SPDP_UNICAST_OFFSET + participant * DDSI_PARTICIPANT_ID_GAIN,
  )
}

///|
/// Return the default user-data multicast port for a DDS domain.
pub fn ddsi_user_multicast_port(domain_id : UInt32) -> Result[Int32, String] {
  ddsi_port(domain_id, DDSI_USER_MULTICAST_OFFSET)
}

///|
/// Return the default user-data unicast port for a domain and participant ID.
pub fn ddsi_user_unicast_port(
  domain_id : UInt32,
  participant_id : UInt32,
) -> Result[Int32, String] {
  let participant = participant_id.reinterpret_as_int()
  if participant < 0 {
    return Err("the DDSI-RTPS participant ID is out of range")
  }
  ddsi_port(
    domain_id,
    DDSI_USER_UNICAST_OFFSET + participant * DDSI_PARTICIPANT_ID_GAIN,
  )
}

///|
/// Return the default SPDP multicast destination for a DDS domain.
pub fn ddsi_default_spdp_multicast_addr(
  domain_id : UInt32,
) -> Result[@socket.Addr, String] {
  let port = match ddsi_spdp_multicast_port(domain_id) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(@socket.Addr::new(DDSI_DEFAULT_MULTICAST_IP, port))
}

///|
/// Return the default SPDP unicast address for an IPv4 participant.
pub fn ddsi_default_spdp_unicast_addr(
  domain_id : UInt32,
  participant_id : UInt32,
  ip : UInt32,
) -> Result[@socket.Addr, String] {
  let port = match ddsi_spdp_unicast_port(domain_id, participant_id) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(@socket.Addr::new(ip, port))
}

///|
/// Return the default user-data multicast address for a DDS domain.
pub fn ddsi_default_user_multicast_addr(
  domain_id : UInt32,
) -> Result[@socket.Addr, String] {
  let port = match ddsi_user_multicast_port(domain_id) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(@socket.Addr::new(DDSI_DEFAULT_MULTICAST_IP, port))
}

///|
/// Return the default user-data unicast address for an IPv4 participant.
pub fn ddsi_default_user_unicast_addr(
  domain_id : UInt32,
  participant_id : UInt32,
  ip : UInt32,
) -> Result[@socket.Addr, String] {
  let port = match ddsi_user_unicast_port(domain_id, participant_id) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(@socket.Addr::new(ip, port))
}

///|
/// Create a participant with the standard DDSI-RTPS locators for IPv4.
///
/// The returned participant advertises both unicast and domain multicast
/// metatraffic/user-data locators and all six standard builtin endpoint bits.
pub fn new_ddsi_participant(
  guid_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  domain_id : UInt32,
  participant_id : UInt32,
  ip : UInt32,
  lease_seconds : Int32,
) -> Result[@rtps.SpdpParticipantData, String] {
  let participant_entity_id = match @rtps.EntityId::new(b"\x00\x00\x01", 0xC1) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(guid_prefix, participant_entity_id),
    vendor_id,
    domain_id,
    lease_seconds,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR |
    @rtps.BUILTIN_ENDPOINT_PUBLICATIONS_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PUBLICATIONS_DETECTOR |
    @rtps.BUILTIN_ENDPOINT_SUBSCRIPTIONS_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_SUBSCRIPTIONS_DETECTOR,
  )
  let metatraffic_unicast = match
    ddsi_default_spdp_unicast_addr(domain_id, participant_id, ip) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let user_unicast = match
    ddsi_default_user_unicast_addr(domain_id, participant_id, ip) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let metatraffic_multicast = match
    ddsi_default_spdp_multicast_addr(domain_id) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let user_multicast = match ddsi_default_user_multicast_addr(domain_id) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  participant.add_metatraffic_unicast(
    match
      ddsi_udp_locator(metatraffic_unicast.ip(), metatraffic_unicast.port()) {
      Ok(value) => value
      Err(message) => return Err(message)
    },
  )
  participant.add_default_unicast(
    match ddsi_udp_locator(user_unicast.ip(), user_unicast.port()) {
      Ok(value) => value
      Err(message) => return Err(message)
    },
  )
  participant.add_metatraffic_multicast(
    match
      ddsi_udp_locator(metatraffic_multicast.ip(), metatraffic_multicast.port()) {
      Ok(value) => value
      Err(message) => return Err(message)
    },
  )
  participant.add_default_multicast(
    match ddsi_udp_locator(user_multicast.ip(), user_multicast.port()) {
      Ok(value) => value
      Err(message) => return Err(message)
    },
  )
  Ok(participant)
}
