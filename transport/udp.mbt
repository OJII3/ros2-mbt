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
/// Return the address selected by the operating system.
pub fn Udp::local_addr(self : Udp) -> @socket.Addr {
  self.server.addr
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
/// Receive the first SEDP endpoint DATA submessage in a UDP datagram.
pub async fn Udp::receive_sedp(
  self : Udp,
  kind : @rtps.SedpEndpointKind,
) -> Result[(@rtps.SedpEndpointData, @socket.Addr), String] {
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
    let endpoint = match
      @rtps.SedpEndpointData::from_data_submessage(kind, data) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    return Ok((endpoint, source))
  }
  Err("RTPS datagram does not contain an SEDP DATA submessage")
}

///|
/// A discovery sample recognized from an RTPS DATA submessage.
pub(all) enum DiscoveryEvent {
  Participant(@rtps.SpdpParticipantData)
  Publication(@rtps.SedpEndpointData)
  Subscription(@rtps.SedpEndpointData)
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
      Err(_) => ()
    }
    match @rtps.SpdpParticipantData::from_data_submessage(data) {
      Ok(participant) =>
        return Ok((DiscoveryEvent::Participant(participant), source))
      Err(_) => continue
    }
  }
  Err("RTPS datagram does not contain a recognized discovery DATA submessage")
}

///|
/// Close the underlying socket.
pub fn Udp::close(self : Udp) -> Unit {
  self.server.close()
}
