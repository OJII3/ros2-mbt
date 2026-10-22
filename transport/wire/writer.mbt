///|
/// A minimal best-effort RTPS DataWriter.
///
/// Reliable delivery, history, and discovery matching are intentionally kept
/// outside this helper. The writer only owns RTPS DATA sequence numbering.
pub struct DataWriter {
  socket : Udp
  destinations : Array[@socket.Addr]
  state : DataWriterState
}

///|
/// Sans-I/O best-effort RTPS writer state.
pub struct DataWriterState {
  guid_prefix : @rtps.GuidPrefix
  vendor_id : @rtps.VendorId
  reader_id : @rtps.EntityId
  writer_id : @rtps.EntityId
  reader_prefix : @rtps.GuidPrefix?
  mut next_sequence_number : Int64
}

///|
/// Create a best-effort writer for one remote RTPS reader.
pub fn DataWriter::new(
  socket : Udp,
  guid_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  reader_id : @rtps.EntityId,
  writer_id : @rtps.EntityId,
  destination : @socket.Addr,
  first_sequence_number : Int64,
) -> Result[DataWriter, String] {
  let state = match
    DataWriterState::new(
      guid_prefix, vendor_id, reader_id, writer_id, first_sequence_number,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ socket, destinations: [destination], state, })
}

///|
/// Create a Sans-I/O best-effort writer state.
pub fn DataWriterState::new(
  guid_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  reader_id : @rtps.EntityId,
  writer_id : @rtps.EntityId,
  first_sequence_number : Int64,
) -> Result[DataWriterState, String] {
  if first_sequence_number < 1L {
    return Err("an RTPS DATA sequence number must be positive")
  }
  Ok({
    guid_prefix,
    vendor_id,
    reader_id,
    writer_id,
    reader_prefix: None,
    next_sequence_number: first_sequence_number,
  })
}

///|
/// Create a writer targeting a discovered SEDP subscription endpoint.
pub fn DataWriter::new_for_subscription(
  socket : Udp,
  guid_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  writer_id : @rtps.EntityId,
  subscription : @rtps.SedpEndpointData,
  first_sequence_number : Int64,
) -> Result[DataWriter, String] {
  if subscription.kind() != Subscription {
    return Err("a DataWriter target must be an SEDP subscription")
  }
  let unicast_locators = subscription.unicast_locators()
  let locators = if unicast_locators.length() > 0 {
    unicast_locators
  } else {
    subscription.multicast_locators()
  }
  if locators.length() == 0 {
    return Err("the discovered subscription has no UDP locators")
  }
  let destinations = match udp_locator_to_addrs(locators) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let writer = match
    DataWriter::new(
      socket,
      guid_prefix,
      vendor_id,
      subscription.endpoint_guid().entity_id(),
      writer_id,
      destinations[0],
      first_sequence_number,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({
    ..writer,
    destinations,
    state: writer.state.with_reader_prefix(
      subscription.endpoint_guid().prefix(),
    ),
  })
}

///|
/// Configure the remote participant prefix used in INFO_DST.
pub fn DataWriterState::with_reader_prefix(
  self : DataWriterState,
  prefix : @rtps.GuidPrefix,
) -> DataWriterState {
  { ..self, reader_prefix: Some(prefix), }
}

///|
/// Add the remote participant destination when this writer targets a discovered endpoint.
fn DataWriterState::message_for_reader(
  self : DataWriterState,
  message : @rtps.Message,
) -> @rtps.Message {
  match self.reader_prefix {
    Some(prefix) => message.with_destination_guid_prefix(prefix)
    None => message
  }
}

///|
/// Return the sequence number that will be used by the next write.
pub fn DataWriter::next_sequence_number(self : DataWriter) -> Int64 {
  self.state.next_sequence_number()
}

///|
/// Return the sequence number that will be used by the next write.
pub fn DataWriterState::next_sequence_number(self : DataWriterState) -> Int64 {
  self.next_sequence_number
}

///|
/// Encode one best-effort payload as one or more RTPS messages without I/O.
pub fn DataWriterState::messages_for_write(
  self : DataWriterState,
  serialized_payload : Bytes,
) -> Result[Array[@rtps.Message], String] {
  let data = @rtps.DataSubmessage::new(
    self.reader_id,
    self.writer_id,
    self.next_sequence_number,
    serialized_payload,
  )
  let messages : Array[@rtps.Message] = []
  if reliable_writer_data_fits_datagram(data) {
    messages.push(
      self.message_for_reader(data.to_message(self.guid_prefix, self.vendor_id)),
    )
  } else {
    let fragments = match reliable_writer_fragment_data(data) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    for fragment in fragments {
      messages.push(
        self.message_for_reader(
          fragment.to_message(self.guid_prefix, self.vendor_id),
        ),
      )
    }
  }
  Ok(messages)
}

///|
/// Mark the current sample sent and advance to the next sequence number.
pub fn DataWriterState::commit_write(self : DataWriterState) -> Unit {
  self.next_sequence_number += 1L
}

///|
/// Send one best-effort serialized payload and advance its sequence number.
pub async fn DataWriter::write(
  self : DataWriter,
  serialized_payload : Bytes,
) -> Result[Unit, String] {
  let messages = match self.state.messages_for_write(serialized_payload) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  for message in messages {
    for destination in self.destinations {
      match self.socket.send_message(message, destination) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    }
  }
  self.state.commit_write()
  Ok(())
}

///|
/// Close the writer's underlying UDP socket.
pub fn DataWriter::close(self : DataWriter) -> Unit {
  self.socket.close()
}
