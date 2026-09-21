///|
/// A minimal best-effort RTPS DataReader for one discovered publication.
pub struct DataReader {
  socket : Udp
  reader_id : @rtps.EntityId
  writer_id : @rtps.EntityId
  writer_prefix : @rtps.GuidPrefix?
  participant_prefix : @rtps.GuidPrefix?
  state : ReliableDataReader
}

///|
/// Create a reader for one local reader entity and one remote writer entity.
pub fn DataReader::new(
  socket : Udp,
  reader_id : @rtps.EntityId,
  writer_id : @rtps.EntityId,
) -> DataReader {
  {
    socket,
    reader_id,
    writer_id,
    writer_prefix: None,
    participant_prefix: None,
    state: ReliableDataReader::new(reader_id, writer_id),
  }
}

///|
/// Create a reader targeting a discovered SEDP publication endpoint.
pub fn DataReader::new_for_publication(
  socket : Udp,
  reader_id : @rtps.EntityId,
  publication : @rtps.SedpEndpointData,
) -> Result[DataReader, String] {
  data_reader_for_publication(socket, None, reader_id, publication)
}

///|
/// Create a discovered reader that also filters INFO_DST for its participant.
pub fn DataReader::new_for_publication_with_prefix(
  socket : Udp,
  participant_prefix : @rtps.GuidPrefix,
  reader_id : @rtps.EntityId,
  publication : @rtps.SedpEndpointData,
) -> Result[DataReader, String] {
  data_reader_for_publication(
    socket,
    Some(participant_prefix),
    reader_id,
    publication,
  )
}

///|
fn data_reader_for_publication(
  socket : Udp,
  participant_prefix : @rtps.GuidPrefix?,
  reader_id : @rtps.EntityId,
  publication : @rtps.SedpEndpointData,
) -> Result[DataReader, String] {
  if publication.kind() != @rtps.SedpEndpointKind::Publication {
    return Err("a DataReader target must be an SEDP publication")
  }
  Ok({
    socket,
    reader_id,
    writer_id: publication.endpoint_guid().entity_id(),
    writer_prefix: Some(publication.endpoint_guid().prefix()),
    participant_prefix,
    state: ReliableDataReader::new(
      reader_id,
      publication.endpoint_guid().entity_id(),
    ),
  })
}

///|
/// Receive one sample from the configured remote writer.
pub async fn DataReader::receive(
  self : DataReader,
) -> Result[(@rtps.DataSubmessage, @socket.Addr), String] {
  while true {
    let (message, source) = match self.socket.receive_message() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    match message.destination_guid_prefix() {
      Ok(Some(destination)) =>
        match self.participant_prefix {
          Some(prefix) if destination != prefix &&
            !transport_guid_prefix_is_unknown(destination) => continue
          _ => ()
        }
      Ok(None) => ()
      Err(_) => continue
    }
    for submessage in message.submessages() {
      match submessage.id() {
        @rtps.SubmessageId::Data => {
          let data = match @rtps.DataSubmessage::from_submessage(submessage) {
            Ok(value) => value
            Err(message) => return Err(message)
          }
          let prefix_matches = match self.writer_prefix {
            Some(prefix) => message.header().guid_prefix() == prefix
            None => true
          }
          if (
              data.reader_id() != self.reader_id &&
              data.reader_id() != @rtps.EntityId::unknown()
            ) ||
            data.writer_id() != self.writer_id ||
            !prefix_matches {
            continue
          }
          match self.state.accept_data(data) {
            Ok(_) => return Ok((data, source))
            Err(_) => continue
          }
        }
        @rtps.SubmessageId::DataFrag => {
          let fragment = match
            @rtps.DataFragSubmessage::from_submessage(submessage) {
            Ok(value) => value
            Err(_) => continue
          }
          let prefix_matches = match self.writer_prefix {
            Some(prefix) => message.header().guid_prefix() == prefix
            None => true
          }
          if !prefix_matches {
            continue
          }
          let data = match self.state.accept_data_frag(fragment) {
            Ok(value) => value
            Err(_) => continue
          }
          match data {
            Some(value) => return Ok((value, source))
            None => continue
          }
        }
        _ => continue
      }
    }
  }
  Err("best-effort reader stopped")
}

///|
/// Close the reader's underlying UDP socket.
pub fn DataReader::close(self : DataReader) -> Unit {
  self.socket.close()
}
