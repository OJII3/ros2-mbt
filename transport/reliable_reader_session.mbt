///|
/// A UDP-backed reliable reader for one discovered publication.
///
/// HEARTBEAT submessages are acknowledged internally. The caller receives
/// only DATA samples, so unrelated RTPS traffic can share the same socket.
pub struct ReliableDataReaderSession {
  socket : Udp
  guid_prefix : @rtps.GuidPrefix
  vendor_id : @rtps.VendorId
  destination : @socket.Addr
  state : ReliableDataReader
}

///|
/// Create a reliable reader for a discovered SEDP publication.
pub fn ReliableDataReaderSession::new_for_publication(
  socket : Udp,
  guid_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  reader_id : @rtps.EntityId,
  publication : @rtps.SedpEndpointData,
) -> Result[ReliableDataReaderSession, String] {
  if publication.kind() != @rtps.SedpEndpointKind::Publication {
    return Err("a reliable reader target must be an SEDP publication")
  }
  let unicast_locators = publication.unicast_locators()
  let locators = if unicast_locators.length() > 0 {
    unicast_locators
  } else {
    publication.multicast_locators()
  }
  if locators.length() == 0 {
    return Err("the discovered publication has no UDP locators")
  }
  let destination = match udp_locator_to_addr(locators[0]) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let writer_id = publication.endpoint_guid().entity_id()
  Ok({
    socket,
    guid_prefix,
    vendor_id,
    destination,
    state: ReliableDataReader::new(reader_id, writer_id),
  })
}

///|
/// Receive DATA and acknowledge any HEARTBEATs encountered on the socket.
pub async fn ReliableDataReaderSession::receive_data(
  self : ReliableDataReaderSession,
) -> Result[(@rtps.DataSubmessage, @socket.Addr), String] {
  while true {
    let (message, source) = match self.socket.receive_message() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    for submessage in message.submessages() {
      match submessage.id() {
        @rtps.SubmessageId::Data => {
          let data = match @rtps.DataSubmessage::from_submessage(submessage) {
            Ok(value) => value
            Err(_) => continue
          }
          match self.state.accept_data(data) {
            Ok(_) => return Ok((data, source))
            Err(_) => continue
          }
        }
        @rtps.SubmessageId::Heartbeat => {
          let heartbeat = match
            @rtps.HeartbeatSubmessage::from_submessage(submessage) {
            Ok(value) => value
            Err(_) => continue
          }
          let acknack = match self.state.acknack_for_heartbeat(heartbeat) {
            Ok(value) => value
            Err(_) => continue
          }
          match
            self.socket.send_acknack(
              acknack,
              self.guid_prefix,
              self.vendor_id,
              self.destination,
            ) {
            Ok(_) => ()
            Err(message) => return Err(message)
          }
        }
        _ => ()
      }
    }
  }
  Err("reliable reader stopped")
}

///|
pub fn ReliableDataReaderSession::sample_count(
  self : ReliableDataReaderSession,
) -> Int {
  self.state.sample_count()
}

///|
pub fn ReliableDataReaderSession::close(
  self : ReliableDataReaderSession,
) -> Unit {
  self.socket.close()
}
