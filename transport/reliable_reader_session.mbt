///|
/// A UDP-backed reliable reader for one discovered publication.
///
/// HEARTBEAT submessages are acknowledged internally. The caller receives
/// only DATA samples, so unrelated RTPS traffic can share the same socket.
pub struct ReliableDataReaderSession {
  socket : Udp
  guid_prefix : @rtps.GuidPrefix
  vendor_id : @rtps.VendorId
  destinations : Array[@socket.Addr]
  writer_prefix : @rtps.GuidPrefix
  state : ReliableDataReader
  mut pending_samples : Array[(@rtps.DataSubmessage, @socket.Addr)]
  mut pending_sample_index : Int
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
  let destinations = match udp_locator_to_addrs(locators) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let writer_id = publication.endpoint_guid().entity_id()
  Ok({
    socket,
    guid_prefix,
    vendor_id,
    destinations,
    writer_prefix: publication.endpoint_guid().prefix(),
    state: ReliableDataReader::new(reader_id, writer_id),
    pending_samples: [],
    pending_sample_index: 0,
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
  self.receive_data_with_optional_writer(None)
}

///|
/// Receive DATA while servicing a reliable writer on the same socket.
pub async fn ReliableDataReaderSession::receive_data_with_writer(
  self : ReliableDataReaderSession,
  writer : ReliableDataWriter,
) -> Result[(@rtps.DataSubmessage, @rtps.SampleIdentity, @socket.Addr), String] {
  self.receive_data_with_optional_writer(Some(writer))
}

///|
/// Receive DATA while optionally servicing a reliable writer on the same socket.
async fn ReliableDataReaderSession::receive_data_with_optional_writer(
  self : ReliableDataReaderSession,
  control_writer : ReliableDataWriter?,
) -> Result[(@rtps.DataSubmessage, @rtps.SampleIdentity, @socket.Addr), String] {
  while true {
    match self.take_pending_sample() {
      Some((data, source)) => {
        let identity = match data.sample_identity(self.writer_prefix) {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        return Ok((data, identity, source))
      }
      None => ()
    }
    let (message, source) = match self.socket.receive_message() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    match message.destination_guid_prefix() {
      Ok(Some(destination)) if destination != self.guid_prefix => continue
      Ok(_) => ()
      Err(_) => continue
    }
    for submessage in message.submessages() {
      match submessage.id() {
        @rtps.SubmessageId::AckNack =>
          match control_writer {
            Some(writer) => {
              let acknack = match
                @rtps.AckNackSubmessage::from_submessage(submessage) {
                Ok(value) => value
                Err(_) => continue
              }
              let prefix_matches = match writer.reader_prefix {
                Some(prefix) => message.header().guid_prefix() == prefix
                None => true
              }
              if acknack.writer_id() != writer.writer_id ||
                acknack.reader_id() != writer.reader_id ||
                !prefix_matches {
                continue
              }
              ignore(writer.handle_acknack(acknack))
            }
            None => ()
          }
        @rtps.SubmessageId::NackFrag =>
          match control_writer {
            Some(writer) => {
              let nackfrag = match
                @rtps.NackFragSubmessage::from_submessage(submessage) {
                Ok(value) => value
                Err(_) => continue
              }
              let prefix_matches = match writer.reader_prefix {
                Some(prefix) => message.header().guid_prefix() == prefix
                None => true
              }
              if nackfrag.writer_id() != writer.writer_id ||
                nackfrag.reader_id() != writer.reader_id ||
                !prefix_matches {
                continue
              }
              ignore(writer.handle_nackfrag(nackfrag))
            }
            None => ()
          }
        @rtps.SubmessageId::Data => {
          if message.header().guid_prefix() != self.writer_prefix {
            continue
          }
          let data = match @rtps.DataSubmessage::from_submessage(submessage) {
            Ok(value) => value
            Err(_) => continue
          }
          if data.reader_id() != self.state.reader_id &&
            data.reader_id() != @rtps.EntityId::unknown() {
            continue
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
          let fragment = match
            @rtps.DataFragSubmessage::from_submessage(submessage) {
            Ok(value) => value
            Err(_) => continue
          }
          if fragment.reader_id() != self.state.reader_id &&
            fragment.reader_id() != @rtps.EntityId::unknown() {
            continue
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
        @rtps.SubmessageId::HeartbeatFrag => {
          if message.header().guid_prefix() != self.writer_prefix {
            continue
          }
          let heartbeat = match
            @rtps.HeartbeatFragSubmessage::from_submessage(submessage) {
            Ok(value) => value
            Err(_) => continue
          }
          ignore(self.acknowledge_heartbeat_frag(heartbeat))
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
  self.receive_related_data_with_optional_writer(request_identity, None)
}

///|
/// Receive a related DATA sample while servicing a writer on the same socket.
pub async fn ReliableDataReaderSession::receive_related_data_with_writer(
  self : ReliableDataReaderSession,
  request_identity : @rtps.SampleIdentity,
  writer : ReliableDataWriter,
) -> Result[(@rtps.DataSubmessage, @socket.Addr), String] {
  self.receive_related_data_with_optional_writer(request_identity, Some(writer))
}

///|
async fn ReliableDataReaderSession::receive_related_data_with_optional_writer(
  self : ReliableDataReaderSession,
  request_identity : @rtps.SampleIdentity,
  control_writer : ReliableDataWriter?,
) -> Result[(@rtps.DataSubmessage, @socket.Addr), String] {
  while true {
    let (data, _, source) = match
      self.receive_data_with_optional_writer(control_writer) {
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
    match message.destination_guid_prefix() {
      Ok(Some(destination)) if destination != self.guid_prefix => continue
      Ok(_) => ()
      Err(_) => continue
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
          if data.reader_id() != self.state.reader_id &&
            data.reader_id() != @rtps.EntityId::unknown() {
            continue
          }
          let already_received = self.state.has_received_sequence(
            data.writer_sequence_number(),
          )
          match self.state.accept_data(data) {
            Ok(_) =>
              if !already_received {
                self.pending_samples.push((data, source))
              }
            Err(_) => ()
          }
        }
        @rtps.SubmessageId::DataFrag => {
          if message.header().guid_prefix() != self.writer_prefix {
            continue
          }
          let fragment = match
            @rtps.DataFragSubmessage::from_submessage(submessage) {
            Ok(value) => value
            Err(_) => continue
          }
          if fragment.reader_id() != self.state.reader_id &&
            fragment.reader_id() != @rtps.EntityId::unknown() {
            continue
          }
          match self.state.accept_data_frag(fragment) {
            Ok(Some(data)) => self.pending_samples.push((data, source))
            Ok(None) => ()
            Err(_) => ()
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
        @rtps.SubmessageId::HeartbeatFrag => {
          if message.header().guid_prefix() != self.writer_prefix {
            continue
          }
          let heartbeat = match
            @rtps.HeartbeatFragSubmessage::from_submessage(submessage) {
            Ok(value) => value
            Err(_) => continue
          }
          match self.acknowledge_heartbeat_frag(heartbeat) {
            Ok(_) => ()
            Err(_) => continue
          }
        }
        _ => ()
      }
    }
  }
  Err("reliable reader stopped")
}

///|
/// Return the next DATA sample consumed while servicing control traffic.
fn ReliableDataReaderSession::take_pending_sample(
  self : ReliableDataReaderSession,
) -> (@rtps.DataSubmessage, @socket.Addr)? {
  if self.pending_sample_index >= self.pending_samples.length() {
    return None
  }
  let result = self.pending_samples[self.pending_sample_index]
  self.pending_sample_index += 1
  if self.pending_sample_index == self.pending_samples.length() {
    self.pending_samples = []
    self.pending_sample_index = 0
  }
  Some(result)
}

///|
async fn ReliableDataReaderSession::acknowledge_heartbeat(
  self : ReliableDataReaderSession,
  heartbeat : @rtps.HeartbeatSubmessage,
) -> Result[Unit, String] {
  let acknacks = match self.state.acknacks_for_heartbeat(heartbeat) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  for acknack in acknacks {
    for destination in self.destinations {
      match
        self.socket.send_message(
          acknack
          .to_message(self.guid_prefix, self.vendor_id)
          .with_destination_guid_prefix(self.writer_prefix),
          destination,
        ) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    }
  }
  Ok(())
}

///|
async fn ReliableDataReaderSession::acknowledge_heartbeat_frag(
  self : ReliableDataReaderSession,
  heartbeat : @rtps.HeartbeatFragSubmessage,
) -> Result[Unit, String] {
  let nackfrags = match self.state.nackfrags_for_heartbeat_frag(heartbeat) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  for nackfrag in nackfrags {
    for destination in self.destinations {
      match
        self.socket.send_message(
          nackfrag
          .to_message(self.guid_prefix, self.vendor_id)
          .with_destination_guid_prefix(self.writer_prefix),
          destination,
        ) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    }
  }
  Ok(())
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
