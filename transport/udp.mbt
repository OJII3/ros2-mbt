///|
/// Maximum size of one UDP datagram accepted by the RTPS transport.
pub const MAX_DATAGRAM_SIZE : Int = 65535

///| A small UDP server wrapper for RTPS datagrams.

///|
/// The wrapper deliberately exposes the async socket boundary without adding
/// RTPS policy. Discovery and user-data layers can share one socket and decide
/// how to dispatch each received datagram.
pub struct Udp {
  server : @socket.UdpServer
}

///|
/// Bind a UDP socket to an address.
pub async fn Udp::bind(addr : @socket.Addr) -> Udp {
  { server: @socket.UdpServer(addr), }
}

///|
/// Bind a socket that receives only the specified multicast group.
pub async fn Udp::multicast(group : @socket.Addr) -> Udp {
  { server: @socket.UdpServer::multicast(group), }
}

///|
/// Bind to the DDSI-RTPS SPDP multicast port for a domain.
pub async fn Udp::ddsi_spdp_multicast(domain_id : UInt) -> Result[Udp, String] {
  let address = match ddsi_default_spdp_multicast_addr(domain_id) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(Udp::multicast(address))
}

///|
/// Bind to a DDSI-RTPS SPDP unicast port.
pub async fn Udp::ddsi_spdp_unicast(
  domain_id : UInt,
  participant_id : UInt,
  ip : UInt,
) -> Result[Udp, String] {
  let address = match
    ddsi_default_spdp_unicast_addr(domain_id, participant_id, ip) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(Udp::bind(address))
}

///|
/// Bind to the DDSI-RTPS user-data multicast port for a domain.
pub async fn Udp::ddsi_user_multicast(domain_id : UInt) -> Result[Udp, String] {
  let address = match ddsi_default_user_multicast_addr(domain_id) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(Udp::multicast(address))
}

///|
/// Bind to a DDSI-RTPS user-data unicast port.
pub async fn Udp::ddsi_user_unicast(
  domain_id : UInt,
  participant_id : UInt,
  ip : UInt,
) -> Result[Udp, String] {
  let address = match
    ddsi_default_user_unicast_addr(domain_id, participant_id, ip) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(Udp::bind(address))
}

///|
/// Return the address selected by the operating system.
pub fn Udp::local_addr(self : Udp) -> @socket.Addr {
  self.server.addr
}

///|
/// Return the bound IPv4 address as an RTPS UDP locator.
pub fn Udp::local_unicast_locator(self : Udp) -> Result[@rtps.Locator, String] {
  let address = self.local_addr()
  ddsi_udp_locator(address.ip(), address.port())
}

///|
/// Join a multicast group on a regular UDP server.
pub fn Udp::join_multicast_group(
  self : Udp,
  group : @socket.Addr,
) -> Unit raise {
  self.server.join_multicast_group(group)
}

///|
/// Send one complete UDP datagram.
pub async fn Udp::send_to(
  self : Udp,
  payload : Bytes,
  destination : @socket.Addr,
) -> Unit {
  self.server.sendto(payload, destination)
}

///|
/// Serialize and send one RTPS message as a complete UDP datagram.
pub async fn Udp::send_message(
  self : Udp,
  message : @rtps.Message,
  destination : @socket.Addr,
) -> Result[Unit, String] {
  let payload = match message.to_bytes() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  self.send_to(payload, destination)
  Ok(())
}

///|
/// Serialize and send one user DATA submessage.
pub async fn Udp::send_data(
  self : Udp,
  data : @rtps.DataSubmessage,
  guid_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  destination : @socket.Addr,
) -> Result[Unit, String] {
  self.send_message(data.to_message(guid_prefix, vendor_id), destination)
}

///|
/// Serialize and send one RTPS DATA_FRAG submessage.
pub async fn Udp::send_data_frag(
  self : Udp,
  data : @rtps.DataFragSubmessage,
  guid_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  destination : @socket.Addr,
) -> Result[Unit, String] {
  self.send_message(data.to_message(guid_prefix, vendor_id), destination)
}

///|
/// Serialize and send one RTPS HEARTBEAT submessage.
pub async fn Udp::send_heartbeat(
  self : Udp,
  heartbeat : @rtps.HeartbeatSubmessage,
  guid_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  destination : @socket.Addr,
) -> Result[Unit, String] {
  self.send_message(heartbeat.to_message(guid_prefix, vendor_id), destination)
}

///|
/// Serialize and send one RTPS HEARTBEAT_FRAG submessage.
pub async fn Udp::send_heartbeat_frag(
  self : Udp,
  heartbeat : @rtps.HeartbeatFragSubmessage,
  guid_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  destination : @socket.Addr,
) -> Result[Unit, String] {
  self.send_message(heartbeat.to_message(guid_prefix, vendor_id), destination)
}

///|
/// Serialize and send one RTPS ACKNACK submessage.
pub async fn Udp::send_acknack(
  self : Udp,
  acknack : @rtps.AckNackSubmessage,
  guid_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  destination : @socket.Addr,
) -> Result[Unit, String] {
  self.send_message(acknack.to_message(guid_prefix, vendor_id), destination)
}

///|
/// Serialize and send one RTPS NACK_FRAG submessage.
pub async fn Udp::send_nack_frag(
  self : Udp,
  nackfrag : @rtps.NackFragSubmessage,
  guid_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  destination : @socket.Addr,
) -> Result[Unit, String] {
  self.send_message(nackfrag.to_message(guid_prefix, vendor_id), destination)
}

///|
/// Serialize and send one SPDP participant announcement.
pub async fn Udp::send_spdp(
  self : Udp,
  participant : @rtps.SpdpParticipantData,
  reader_id : @rtps.EntityId,
  writer_id : @rtps.EntityId,
  writer_sequence_number : Int64,
  destination : @socket.Addr,
) -> Result[Unit, String] {
  let message = participant.to_message(
    reader_id, writer_id, writer_sequence_number,
  )
  self.send_message(message, destination)
}

///|
/// Receive one complete UDP datagram and its source address.
pub async fn Udp::receive(self : Udp) -> (Bytes, @socket.Addr) {
  let buffer : FixedArray[Byte] = FixedArray::make(MAX_DATAGRAM_SIZE, 0)
  let (length, source) = self.server.recvfrom(buffer, max_len=MAX_DATAGRAM_SIZE)
  (Bytes::from_array(buffer[:length]), source)
}

///|
/// Receive and parse one RTPS message from a UDP datagram.
pub async fn Udp::receive_message(
  self : Udp,
) -> Result[(@rtps.Message, @socket.Addr), String] {
  let (payload, source) = self.receive()
  let message = match @rtps.Message::from_bytes(payload) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok((message, source))
}

///|
/// Receive and parse the first DATA submessage in a UDP datagram.
pub async fn Udp::receive_data(
  self : Udp,
) -> Result[(@rtps.DataSubmessage, @socket.Addr), String] {
  let (message, source) = match self.receive_message() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  for submessage in message.submessages() {
    if submessage.id() != @rtps.SubmessageId::Data {
      continue
    }
    let data = match @rtps.DataSubmessage::from_submessage(submessage) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    return Ok((data, source))
  }
  Err("RTPS datagram does not contain a DATA submessage")
}

///|
/// Serialize and send one ROS graph-discovery sample as RTPS DATA.
pub async fn Udp::send_ros_discovery_info(
  self : Udp,
  info : @ros.ParticipantEntitiesInfo,
  guid_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  reader_id : @rtps.EntityId,
  writer_id : @rtps.EntityId,
  writer_sequence_number : Int64,
  destination : @socket.Addr,
) -> Result[Unit, String] {
  let data = @rtps.DataSubmessage::new(
    reader_id,
    writer_id,
    writer_sequence_number,
    info.to_cdr_bytes(),
  )
  self.send_data(data, guid_prefix, vendor_id, destination)
}

///|
/// Receive and decode one ROS graph-discovery DATA sample.
pub async fn Udp::receive_ros_discovery_info(
  self : Udp,
) -> Result[(@ros.ParticipantEntitiesInfo, @socket.Addr), String] {
  let (data, source) = match self.receive_data() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let info = match
    @ros.ParticipantEntitiesInfo::from_cdr_bytes(data.serialized_payload()) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok((info, source))
}

///|
/// Receive and parse the first HEARTBEAT submessage in a UDP datagram.
pub async fn Udp::receive_heartbeat(
  self : Udp,
) -> Result[(@rtps.HeartbeatSubmessage, @socket.Addr), String] {
  let (message, source) = match self.receive_message() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  for submessage in message.submessages() {
    if submessage.id() != @rtps.SubmessageId::Heartbeat {
      continue
    }
    let heartbeat = match
      @rtps.HeartbeatSubmessage::from_submessage(submessage) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    return Ok((heartbeat, source))
  }
  Err("RTPS datagram does not contain a HEARTBEAT submessage")
}

///|
/// Receive and parse the first ACKNACK submessage in a UDP datagram.
pub async fn Udp::receive_acknack(
  self : Udp,
) -> Result[(@rtps.AckNackSubmessage, @socket.Addr), String] {
  let (message, source) = match self.receive_message() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  for submessage in message.submessages() {
    if submessage.id() != @rtps.SubmessageId::AckNack {
      continue
    }
    let acknack = match @rtps.AckNackSubmessage::from_submessage(submessage) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    return Ok((acknack, source))
  }
  Err("RTPS datagram does not contain an ACKNACK submessage")
}

///|
/// Receive and parse the first NACK_FRAG submessage in a UDP datagram.
pub async fn Udp::receive_nack_frag(
  self : Udp,
) -> Result[(@rtps.NackFragSubmessage, @socket.Addr), String] {
  let (message, source) = match self.receive_message() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  for submessage in message.submessages() {
    if submessage.id() != @rtps.SubmessageId::NackFrag {
      continue
    }
    let nackfrag = match @rtps.NackFragSubmessage::from_submessage(submessage) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    return Ok((nackfrag, source))
  }
  Err("RTPS datagram does not contain a NACK_FRAG submessage")
}

///|
/// Receive the first SPDP DATA submessage in a UDP datagram.
pub async fn Udp::receive_spdp(
  self : Udp,
) -> Result[(@rtps.SpdpParticipantData, @socket.Addr), String] {
  let (message, source) = match self.receive_message() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  for submessage in message.submessages() {
    if submessage.id() != @rtps.SubmessageId::Data {
      continue
    }
    let data = match @rtps.DataSubmessage::from_submessage(submessage) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let participant = match
      @rtps.SpdpParticipantData::from_data_submessage(data) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    return Ok((participant, source))
  }
  Err("RTPS datagram does not contain an SPDP DATA submessage")
}

///|
/// Serialize and send one SEDP endpoint announcement.
pub async fn Udp::send_sedp(
  self : Udp,
  endpoint : @rtps.SedpEndpointData,
  vendor_id : @rtps.VendorId,
  reader_id : @rtps.EntityId,
  writer_id : @rtps.EntityId,
  writer_sequence_number : Int64,
  destination : @socket.Addr,
) -> Result[Unit, String] {
  let message = match
    endpoint.to_message(vendor_id, reader_id, writer_id, writer_sequence_number) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  self.send_message(message, destination)
}

///|
fn udp_locator_to_addr(locator : @rtps.Locator) -> Result[@socket.Addr, String] {
  if locator.kind() != @rtps.LOCATOR_KIND_UDP_V4 {
    return Err("only UDP/IPv4 RTPS locators are supported")
  }
  let address = locator.address()
  let ip : UInt = (address[12].to_int().reinterpret_as_uint() << 24) |
    (address[13].to_int().reinterpret_as_uint() << 16) |
    (address[14].to_int().reinterpret_as_uint() << 8) |
    address[15].to_int().reinterpret_as_uint()
  Ok(@socket.Addr::new(ip, locator.port().reinterpret_as_int()))
}

///|
/// Convert all supported UDP/IPv4 locators, ignoring other transport kinds.
fn udp_locator_to_addrs(
  locators : Array[@rtps.Locator],
) -> Result[Array[@socket.Addr], String] {
  let addresses : Array[@socket.Addr] = []
  for locator in locators {
    if locator.kind() != @rtps.LOCATOR_KIND_UDP_V4 {
      continue
    }
    addresses.push(
      match udp_locator_to_addr(locator) {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
  }
  if addresses.length() == 0 {
    return Err("no supported UDP/IPv4 locators were advertised")
  }
  Ok(addresses)
}

///|
/// Send an SEDP announcement to all metatraffic locators in an SPDP sample.
pub async fn Udp::send_sedp_to_participant(
  self : Udp,
  endpoint : @rtps.SedpEndpointData,
  vendor_id : @rtps.VendorId,
  remote_participant : @rtps.SpdpParticipantData,
  writer_sequence_number : Int64,
) -> Result[Unit, String] {
  self.send_sedp_to_participant_with_heartbeat_count(
    endpoint, vendor_id, remote_participant, writer_sequence_number, 1U,
  )
}

///|
/// Send an SEDP announcement with an explicit reliable HEARTBEAT count.
pub async fn Udp::send_sedp_to_participant_with_heartbeat_count(
  self : Udp,
  endpoint : @rtps.SedpEndpointData,
  vendor_id : @rtps.VendorId,
  remote_participant : @rtps.SpdpParticipantData,
  writer_sequence_number : Int64,
  heartbeat_count : UInt,
) -> Result[Unit, String] {
  let kind = endpoint.kind()
  let reader_id = kind.builtin_reader_id()
  let writer_id = kind.builtin_writer_id()
  let unicast_locators = remote_participant.metatraffic_unicast_locators()
  let locators = if unicast_locators.length() > 0 {
    unicast_locators
  } else {
    remote_participant.metatraffic_multicast_locators()
  }
  if locators.length() == 0 {
    return Err("the remote participant has no metatraffic locators")
  }
  let destinations = match udp_locator_to_addrs(locators) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  for destination in destinations {
    let endpoint_message = match
      endpoint.to_message(vendor_id, reader_id, writer_id, writer_sequence_number) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    match
      self.send_message(
        endpoint_message.with_destination_guid_prefix(
          remote_participant.participant_guid().prefix(),
        ),
        destination,
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    let heartbeat = match
      @rtps.HeartbeatSubmessage::new(
        reader_id, writer_id, writer_sequence_number, writer_sequence_number, heartbeat_count,
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    match
      self.send_message(
        heartbeat.to_message(
          endpoint.participant_guid().prefix(),
          vendor_id,
        ).with_destination_guid_prefix(
          remote_participant.participant_guid().prefix(),
        ),
        destination,
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(())
}

///| Send an SEDP endpoint dispose sample to all advertised metatraffic locators.
pub async fn Udp::send_sedp_dispose_to_participant(
  self : Udp,
  endpoint : @rtps.SedpEndpointData,
  vendor_id : @rtps.VendorId,
  remote_participant : @rtps.SpdpParticipantData,
  writer_sequence_number : Int64,
) -> Result[Unit, String] {
  self.send_sedp_dispose_to_participant_with_heartbeat_count(
    endpoint, vendor_id, remote_participant, writer_sequence_number, 1U,
  )
}

///| Send an SEDP endpoint dispose with an explicit reliable HEARTBEAT count.
pub async fn Udp::send_sedp_dispose_to_participant_with_heartbeat_count(
  self : Udp,
  endpoint : @rtps.SedpEndpointData,
  vendor_id : @rtps.VendorId,
  remote_participant : @rtps.SpdpParticipantData,
  writer_sequence_number : Int64,
  heartbeat_count : UInt,
) -> Result[Unit, String] {
  let kind = endpoint.kind()
  let reader_id = kind.builtin_reader_id()
  let writer_id = kind.builtin_writer_id()
  let unicast_locators = remote_participant.metatraffic_unicast_locators()
  let locators = if unicast_locators.length() > 0 {
    unicast_locators
  } else {
    remote_participant.metatraffic_multicast_locators()
  }
  if locators.length() == 0 {
    return Err("the remote participant has no metatraffic locators")
  }
  let destinations = match udp_locator_to_addrs(locators) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  for destination in destinations {
    let endpoint_message = endpoint.to_dispose_data_submessage(
      reader_id,
      writer_id,
      writer_sequence_number,
    ).to_message(
      endpoint.participant_guid().prefix(),
      vendor_id,
    ).with_destination_guid_prefix(
      remote_participant.participant_guid().prefix(),
    )
    match self.send_message(endpoint_message, destination) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    let heartbeat = match
      @rtps.HeartbeatSubmessage::new(
        reader_id, writer_id, writer_sequence_number, writer_sequence_number,
        heartbeat_count,
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    match
      self.send_message(
        heartbeat.to_message(
          endpoint.participant_guid().prefix(),
          vendor_id,
        ).with_destination_guid_prefix(
          remote_participant.participant_guid().prefix(),
        ),
        destination,
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(())
}

///|
/// Receive the first SEDP endpoint DATA submessage in a UDP datagram.
pub async fn Udp::receive_sedp(
  self : Udp,
  kind : @rtps.SedpEndpointKind,
) -> Result[(@rtps.SedpEndpointData, @socket.Addr), String] {
  while true {
    let (message, source) = match self.receive_message() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    for submessage in message.submessages() {
      if submessage.id() != @rtps.SubmessageId::Data {
        continue
      }
      let data = match @rtps.DataSubmessage::from_submessage(submessage) {
        Ok(value) => value
        Err(_) => continue
      }
      let endpoint = match
        @rtps.SedpEndpointData::from_data_submessage(kind, data) {
        Ok(value) => value
        Err(_) => continue
      }
      return Ok((endpoint, source))
    }
  }
  Err("SEDP receive loop stopped")
}

///|
/// A discovery sample recognized from an RTPS DATA submessage.
pub(all) enum DiscoveryEvent {
  Participant(@rtps.SpdpParticipantData)
  Publication(@rtps.SedpEndpointData)
  Subscription(@rtps.SedpEndpointData)
  EndpointRemoved(@rtps.SedpEndpointKind, @rtps.Guid)
  ParticipantRemoved(@rtps.Guid)
}

///|
/// Receive the first recognized SPDP or SEDP sample in a UDP datagram.
///
/// SEDP publication/subscription samples are distinguished by their
/// predefined builtin writer entity IDs. Unknown DATA samples are skipped so
/// that a shared discovery socket can also carry unrelated RTPS traffic.
pub async fn Udp::receive_discovery(
  self : Udp,
) -> Result[(DiscoveryEvent, @socket.Addr), String] {
  while true {
    let (message, source) = match self.receive_message() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    for submessage in message.submessages() {
      if submessage.id() != @rtps.SubmessageId::Data {
        continue
      }
      let data = match @rtps.DataSubmessage::from_submessage(submessage) {
        Ok(value) => value
        Err(_) => continue
      }
      match @rtps.SedpEndpointKind::from_builtin_writer_id(data.writer_id()) {
        Ok(kind) => {
          let status = match data.status_info() {
            Ok(value) => value
            Err(_) => continue
          }
          match status {
            Some(value) if
              (value &
                (@rtps.STATUS_INFO_DISPOSED |
                  @rtps.STATUS_INFO_UNREGISTERED)) != 0U => {
              if (data.flags() & @rtps.DATA_FLAG_KEY) == 0 {
                continue
              }
              let endpoint_guid = match
                @rtps.SedpEndpointData::endpoint_guid_from_key_data(data) {
                Ok(value) => value
                Err(_) => continue
              }
              return Ok((DiscoveryEvent::EndpointRemoved(kind, endpoint_guid), source))
            }
            _ => ()
          }
          let endpoint = match
            @rtps.SedpEndpointData::from_data_submessage(kind, data) {
            Ok(value) => value
            Err(_) => continue
          }
          match kind {
            @rtps.SedpEndpointKind::Publication =>
              return Ok((DiscoveryEvent::Publication(endpoint), source))
            @rtps.SedpEndpointKind::Subscription =>
              return Ok((DiscoveryEvent::Subscription(endpoint), source))
          }
        }
        Err(_) => {
          let status = match data.status_info() {
            Ok(value) => value
            Err(_) => continue
          }
          match status {
            Some(value) if
              (value &
                (@rtps.STATUS_INFO_DISPOSED |
                  @rtps.STATUS_INFO_UNREGISTERED)) != 0U => {
              if (data.flags() & @rtps.DATA_FLAG_KEY) == 0 {
                continue
              }
              let participant_guid = match
                @rtps.SpdpParticipantData::participant_guid_from_key_data(data) {
                Ok(value) => value
                Err(_) => continue
              }
              return Ok((DiscoveryEvent::ParticipantRemoved(participant_guid), source))
            }
            _ => ()
          }
        }
      }
      match @rtps.SpdpParticipantData::from_data_submessage(data) {
        Ok(participant) =>
          return Ok((DiscoveryEvent::Participant(participant), source))
        Err(_) => continue
      }
    }
  }
  Err("discovery receive loop stopped")
}

///|
/// Close the underlying socket.
pub fn Udp::close(self : Udp) -> Unit {
  self.server.close()
}
