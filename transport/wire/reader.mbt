///|
/// A minimal best-effort RTPS DataReader for one discovered publication.
///
/// Receive history covers the latest 256 sequence numbers. Fragment reassembly
/// retains at most four incomplete samples with 16 MiB of payload in total.
/// Older samples are discarded in favor of newer ones when these limits apply.
pub struct DataReader {
  socket : Udp
  state : DataReaderState
}

///|
/// Sans-I/O best-effort RTPS reader state for one remote writer.
pub struct DataReaderState {
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
  { socket, state: DataReaderState::new(reader_id, writer_id), }
}

///|
/// Create a Sans-I/O reader for one local reader entity and one remote writer.
pub fn DataReaderState::new(
  reader_id : @rtps.EntityId,
  writer_id : @rtps.EntityId,
) -> DataReaderState {
  {
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
  match
    DataReaderState::new_for_publication(
      reader_id, publication, participant_prefix,
    ) {
    Ok(state) => Ok({ socket, state, })
    Err(message) => Err(message)
  }
}

///|
/// Create a Sans-I/O reader targeting a discovered SEDP publication endpoint.
pub fn DataReaderState::new_for_publication(
  reader_id : @rtps.EntityId,
  publication : @rtps.SedpEndpointData,
  participant_prefix : @rtps.GuidPrefix?,
) -> Result[DataReaderState, String] {
  if publication.kind() != Publication {
    return Err("a DataReader target must be an SEDP publication")
  }
  Ok({
    ..DataReaderState::new(reader_id, publication.endpoint_guid().entity_id()),
    writer_prefix: Some(publication.endpoint_guid().prefix()),
    participant_prefix,
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
    match self.state.handle_message(message) {
      Ok(Some(data)) => return Ok((data, source))
      Ok(None) => continue
      Err(message) => return Err(message)
    }
  }
  Err("best-effort reader stopped")
}

///|
/// Process one already-received RTPS message for this reader.
pub fn DataReader::handle_message(
  self : DataReader,
  message : @rtps.Message,
  source : @socket.Addr,
) -> Result[(@rtps.DataSubmessage, @socket.Addr)?, String] {
  match self.state.handle_message(message) {
    Ok(Some(data)) => Ok(Some((data, source)))
    Ok(None) => Ok(None)
    Err(message) => Err(message)
  }
}

///|
/// Process one already-received RTPS message without performing I/O.
pub fn DataReaderState::handle_message(
  self : DataReaderState,
  message : @rtps.Message,
) -> Result[@rtps.DataSubmessage?, String] {
  let destinations = match message.destination_contexts() {
    Ok(value) => value
    Err(_) => return Ok(None)
  }
  let submessages = message.submessages()
  for index in 0..<submessages.length() {
    let submessage = submessages[index]
    if !transport_destination_matches(
        destinations[index],
        self.participant_prefix,
      ) {
      continue
    }
    match submessage.id() {
      Data => {
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
        if self.state.has_received_sequence(data.writer_sequence_number()) {
          continue
        }
        match self.state.accept_data(data) {
          Ok(_) => {
            self.state.prune_best_effort_receive_state(
              data.writer_sequence_number(),
            )
            return Ok(Some(data))
          }
          Err(_) => continue
        }
      }
      DataFrag => {
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
        let data = match self.state.accept_best_effort_fragment(fragment) {
          Ok(value) => value
          Err(_) => continue
        }
        match data {
          Some(value) => return Ok(Some(value))
          None => continue
        }
      }
      _ => continue
    }
  }
  Ok(None)
}

///|
/// Close the reader's underlying UDP socket.
pub fn DataReader::close(self : DataReader) -> Unit {
  self.socket.close()
}
