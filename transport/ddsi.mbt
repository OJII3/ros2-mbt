///|
/// DDSI-RTPS default port base.
pub const DDSI_PORT_BASE : Int = 7400

///|
/// DDSI-RTPS port gain between domain IDs.
pub const DDSI_DOMAIN_ID_GAIN : Int = 250

///|
/// DDSI-RTPS port gain between participant IDs.
pub const DDSI_PARTICIPANT_ID_GAIN : Int = 2

///|
/// DDSI-RTPS SPDP multicast port offset.
pub const DDSI_SPDP_MULTICAST_OFFSET : Int = 0

///|
/// DDSI-RTPS SPDP unicast port offset.
pub const DDSI_SPDP_UNICAST_OFFSET : Int = 10

///|
/// Default DDSI-RTPS IPv4 multicast address, 239.255.0.1.
pub const DDSI_DEFAULT_MULTICAST_IP : UInt = 0xEFFF0001

///|
/// DDSI-RTPS user-data multicast port offset.
pub const DDSI_USER_MULTICAST_OFFSET : Int = 1

///|
/// DDSI-RTPS user-data unicast port offset.
pub const DDSI_USER_UNICAST_OFFSET : Int = 11

///|
fn ddsi_port(domain_id : UInt, offset : Int) -> Result[Int, String] {
  let port = DDSI_PORT_BASE +
    domain_id.reinterpret_as_int() * DDSI_DOMAIN_ID_GAIN +
    offset
  if port < 1 || port > 65535 {
    return Err("the DDSI-RTPS port is outside the UDP port range")
  }
  Ok(port)
}

///|
/// Return the default SPDP multicast port for a DDS domain.
pub fn ddsi_spdp_multicast_port(domain_id : UInt) -> Result[Int, String] {
  ddsi_port(domain_id, DDSI_SPDP_MULTICAST_OFFSET)
}

///|
/// Return the default SPDP unicast port for a domain and participant ID.
pub fn ddsi_spdp_unicast_port(
  domain_id : UInt,
  participant_id : UInt,
) -> Result[Int, String] {
  ddsi_port(
    domain_id,
    DDSI_SPDP_UNICAST_OFFSET +
    participant_id.reinterpret_as_int() * DDSI_PARTICIPANT_ID_GAIN,
  )
}

///|
/// Return the default user-data multicast port for a DDS domain.
pub fn ddsi_user_multicast_port(domain_id : UInt) -> Result[Int, String] {
  ddsi_port(domain_id, DDSI_USER_MULTICAST_OFFSET)
}

///|
/// Return the default user-data unicast port for a domain and participant ID.
pub fn ddsi_user_unicast_port(
  domain_id : UInt,
  participant_id : UInt,
) -> Result[Int, String] {
  ddsi_port(
    domain_id,
    DDSI_USER_UNICAST_OFFSET +
    participant_id.reinterpret_as_int() * DDSI_PARTICIPANT_ID_GAIN,
  )
}

///|
/// Return the default SPDP multicast destination for a DDS domain.
pub fn ddsi_default_spdp_multicast_addr(
  domain_id : UInt,
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
  domain_id : UInt,
  participant_id : UInt,
  ip : UInt,
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
  domain_id : UInt,
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
  domain_id : UInt,
  participant_id : UInt,
  ip : UInt,
) -> Result[@socket.Addr, String] {
  let port = match ddsi_user_unicast_port(domain_id, participant_id) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(@socket.Addr::new(ip, port))
}
