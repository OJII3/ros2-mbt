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
/// Close the underlying socket.
pub fn Udp::close(self : Udp) -> Unit {
  self.server.close()
}
