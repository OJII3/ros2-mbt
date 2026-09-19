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
  writer_prefix : @rtps.GuidPrefix
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
    writer_prefix: publication.endpoint_guid().prefix(),
    state: ReliableDataReader::new(reader_id, writer_id),
  })
}

///|
/// Receive DATA and acknowledge any HEARTBEATs encountered on the socket.
pub async fn ReliableDataReaderSession::receive_data(
  self : ReliableDataReaderSession,
) -> Result[(@rtps.DataSubmessage, @socket.Addr), String] {
  match self.receive_data_with_identity() {
    Ok((data, _, source)) => Ok((data, source))
    Err(message) => Err(message)
  }
}

///|
/// Receive DATA and return its RTPS sample identity.
pub async fn ReliableDataReaderSession::receive_data_with_identity(
  self : ReliableDataReaderSession,
) -> Result[(@rtps.DataSubmessage, @rtps.SampleIdentity, @socket.Addr), String] {
  while true {
    let (message, source) = match self.socket.receive_message() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    for submessage in message.submessages() {
      match submessage.id() {
        @rtps.SubmessageId::Data => {
          if message.header().guid_prefix() != self.writer_prefix {
            continue
          }
          let data = match @rtps.DataSubmessage::from_submessage(submessage) {
            Ok(value) => value
            Err(_) => continue
          }
          match self.state.accept_data(data) {
            Ok(_) => {
              let identity = match
                data.sample_identity(message.header().guid_prefix()) {
                Ok(value) => value
                Err(_) => continue
              }
              return Ok((data, identity, source))
            }
            Err(_) => continue
          }
        }
        @rtps.SubmessageId::DataFrag => {
          if message.header().guid_prefix() != self.writer_prefix {
            continue
          }
          let fragment = match @rtps.DataFragSubmessage::from_submessage(submessage) {
            Ok(value) => value
            Err(_) => continue
          }
          let data = match self.state.accept_data_frag(fragment) {
            Ok(value) => value
            Err(_) => continue
          }
          match data {
            Some(value) => {
              let identity = match
                value.sample_identity(message.header().guid_prefix()) {
                Ok(identity) => identity
                Err(_) => continue
              }
              return Ok((value, identity, source))
            }
            None => ()
          }
        }
        @rtps.SubmessageId::Heartbeat => {
          if message.header().guid_prefix() != self.writer_prefix {
            continue
          }
          let heartbeat = match
            @rtps.HeartbeatSubmessage::from_submessage(submessage) {
            Ok(value) => value
            Err(_) => continue
          }
          match self.acknowledge_heartbeat(heartbeat) {
            Ok(_) => ()
            Err(_) => continue
          }
        }
        @rtps.SubmessageId::Gap => {
          if message.header().guid_prefix() != self.writer_prefix {
            continue
          }
          let gap = match @rtps.GapSubmessage::from_submessage(submessage) {
            Ok(value) => value
            Err(_) => continue
          }
          ignore(self.state.accept_gap(gap))
        }
        _ => ()
      }
    }
  }
  Err("reliable reader stopped")
}

///|
/// Receive DATA until a reply referring to the requested sample arrives.
pub async fn ReliableDataReaderSession::receive_related_data(
  self : ReliableDataReaderSession,
  request_identity : @rtps.SampleIdentity,
) -> Result[(@rtps.DataSubmessage, @socket.Addr), String] {
  while true {
    let (data, _, source) = match self.receive_data_with_identity() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let related = match data.related_sample_identity() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    match related {
      Some(identity) if identity == request_identity =>
        return Ok((data, source))
      _ => ()
    }
  }
  Err("reliable related-data reader stopped")
}

///|
/// Receive a HEARTBEAT, acknowledge it, and return it to the caller.
pub async fn ReliableDataReaderSession::receive_heartbeat(
  self : ReliableDataReaderSession,
) -> Result[(@rtps.HeartbeatSubmessage, @socket.Addr), String] {
  while true {
    let (message, source) = match self.socket.receive_message() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    for submessage in message.submessages() {
      match submessage.id() {
        @rtps.SubmessageId::Data => {
          if message.header().guid_prefix() != self.writer_prefix {
            continue
          }
          let data = match @rtps.DataSubmessage::from_submessage(submessage) {
            Ok(value) => value
            Err(_) => continue
          }
          match self.state.accept_data(data) {
            Ok(_) => ()
            Err(_) => ()
          }
        }
        @rtps.SubmessageId::DataFrag => {
          if message.header().guid_prefix() != self.writer_prefix {
            continue
          }
          let fragment = match @rtps.DataFragSubmessage::from_submessage(submessage) {
            Ok(value) => value
            Err(_) => continue
          }
          ignore(self.state.accept_data_frag(fragment))
        }
        @rtps.SubmessageId::Heartbeat => {
          if message.header().guid_prefix() != self.writer_prefix {
            continue
          }
          let heartbeat = match
            @rtps.HeartbeatSubmessage::from_submessage(submessage) {
            Ok(value) => value
            Err(_) => continue
          }
          if (
              heartbeat.reader_id() != self.state.reader_id &&
              heartbeat.reader_id() != @rtps.EntityId::unknown()
            ) ||
            heartbeat.writer_id() != self.state.writer_id {
            continue
          }
          match self.acknowledge_heartbeat(heartbeat) {
            Ok(_) => return Ok((heartbeat, source))
            Err(message) => return Err(message)
          }
        }
        @rtps.SubmessageId::Gap => {
          if message.header().guid_prefix() != self.writer_prefix {
            continue
          }
          let gap = match @rtps.GapSubmessage::from_submessage(submessage) {
            Ok(value) => value
            Err(_) => continue
          }
          ignore(self.state.accept_gap(gap))
        }
        _ => ()
      }
    }
  }
  Err("reliable reader stopped")
}

///|
async fn ReliableDataReaderSession::acknowledge_heartbeat(
  self : ReliableDataReaderSession,
  heartbeat : @rtps.HeartbeatSubmessage,
) -> Result[Unit, String] {
  let acknack = match self.state.acknack_for_heartbeat(heartbeat) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  self.socket.send_acknack(
    acknack,
    self.guid_prefix,
    self.vendor_id,
    self.destination,
  )
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
