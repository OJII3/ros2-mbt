///|
/// A minimal best-effort RTPS DataReader for one discovered publication.
pub struct DataReader {
  socket : Udp
  reader_id : @rtps.EntityId
  writer_id : @rtps.EntityId
}

///|
/// Create a reader for one local reader entity and one remote writer entity.
pub fn DataReader::new(
  socket : Udp,
  reader_id : @rtps.EntityId,
  writer_id : @rtps.EntityId,
) -> DataReader {
  { socket, reader_id, writer_id, }
}

///|
/// Create a reader targeting a discovered SEDP publication endpoint.
pub fn DataReader::new_for_publication(
  socket : Udp,
  reader_id : @rtps.EntityId,
  publication : @rtps.SedpEndpointData,
) -> Result[DataReader, String] {
  if publication.kind() != @rtps.SedpEndpointKind::Publication {
    return Err("a DataReader target must be an SEDP publication")
  }
  Ok(
    DataReader::new(socket, reader_id, publication.endpoint_guid().entity_id()),
  )
}

///|
/// Receive one sample from the configured remote writer.
pub async fn DataReader::receive(
  self : DataReader,
) -> Result[(@rtps.DataSubmessage, @socket.Addr), String] {
  let (data, source) = match self.socket.receive_data() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if data.reader_id() != self.reader_id {
    return Err("the received DATA targets a different RTPS reader")
  }
  if data.writer_id() != self.writer_id {
    return Err("the received DATA comes from a different RTPS writer")
  }
  Ok((data, source))
}

///|
/// Close the reader's underlying UDP socket.
pub fn DataReader::close(self : DataReader) -> Unit {
  self.socket.close()
}
