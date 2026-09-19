///|
/// A native UDP ROS 2 participant with discovery and user-data sockets.
///
/// This type owns the socket lifecycle, while endpoint matching and message
/// serialization remain explicit in the existing topic facades.
pub struct RosParticipant {
  participant : @rtps.SpdpParticipantData
  discovery : DiscoveryService
  user_socket : Udp
  user_locator : @rtps.Locator
}

///|
/// Build a participant from already-bound sockets.
///
/// This constructor is useful when an application needs custom socket
/// binding. The discovery session still announces to the DDSI multicast
/// address for `domain_id`.
pub fn RosParticipant::from_sockets(
  discovery_socket : Udp,
  user_socket : Udp,
  participant : @rtps.SpdpParticipantData,
  domain_id : UInt,
  first_sequence_number : Int64,
) -> Result[RosParticipant, String] {
  let user_locator = match user_socket.local_unicast_locator() {
    Ok(value) => value
    Err(message) => {
      discovery_socket.close()
      user_socket.close()
      return Err(message)
    }
  }
  let session = match
    DiscoverySession::new_default(
      discovery_socket, participant, domain_id, first_sequence_number,
    ) {
    Ok(value) => value
    Err(message) => {
      user_socket.close()
      return Err(message)
    }
  }
  Ok({
    participant,
    discovery: DiscoveryService::new(session),
    user_socket,
    user_locator,
  })
}

///|
/// Build a participant using the standard DDSI-RTPS IPv4 ports.
pub async fn RosParticipant::new_ddsi(
  guid_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  domain_id : UInt,
  participant_id : UInt,
  ip : UInt,
  lease_seconds : Int,
  first_sequence_number : Int64,
) -> Result[RosParticipant, String] {
  let participant = match
    new_ddsi_participant(
      guid_prefix, vendor_id, domain_id, participant_id, ip, lease_seconds,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let discovery_socket = match Udp::ddsi_spdp_multicast(domain_id) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let user_socket = match
    Udp::ddsi_user_unicast(domain_id, participant_id, ip) {
    Ok(value) => value
    Err(message) => {
      discovery_socket.close()
      return Err(message)
    }
  }
  RosParticipant::from_sockets(
    discovery_socket, user_socket, participant, domain_id, first_sequence_number,
  )
}

///|
/// Return the local SPDP participant data.
pub fn RosParticipant::participant(
  self : RosParticipant,
) -> @rtps.SpdpParticipantData {
  self.participant
}

///|
/// Return the locator advertised for the bound user-data socket.
pub fn RosParticipant::user_locator(self : RosParticipant) -> @rtps.Locator {
  self.user_locator
}

///|
/// Return the current discovery graph.
pub fn RosParticipant::graph(self : RosParticipant) -> DiscoveryGraph {
  self.discovery.graph()
}

///|
/// Send one SPDP participant announcement.
pub async fn RosParticipant::announce_spdp_once(
  self : RosParticipant,
) -> Result[Unit, String] {
  self.discovery.announce_once()
}

///|
/// Receive one SPDP or SEDP event and ingest it into the graph.
pub async fn RosParticipant::receive_discovery_once(
  self : RosParticipant,
) -> Result[(@socket.Addr, DiscoveryEvent), String] {
  self.discovery.receive_once()
}

///|
/// Transfer ownership of both underlying services to the caller.
pub fn RosParticipant::into_parts(
  self : RosParticipant,
) -> (DiscoveryService, Udp) {
  (self.discovery, self.user_socket)
}

///|
/// Close both discovery and user-data sockets.
pub fn RosParticipant::close(self : RosParticipant) -> Unit {
  self.discovery.close()
  self.user_socket.close()
}
