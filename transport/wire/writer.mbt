///|
/// A minimal best-effort RTPS DataWriter.
///
/// Reliable delivery, history, and discovery matching are intentionally kept
/// outside this helper. The writer only owns RTPS DATA sequence numbering.
pub struct DataWriter {
  socket : Udp
  guid_prefix : @rtps.GuidPrefix
  vendor_id : @rtps.VendorId
  reader_id : @rtps.EntityId
  writer_id : @rtps.EntityId
  destinations : Array[@socket.Addr]
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
  if first_sequence_number < 1L {
    return Err("an RTPS DATA sequence number must be positive")
  }
  Ok({
    socket,
    guid_prefix,
    vendor_id,
    reader_id,
    writer_id,
    destinations: [destination],
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
  if subscription.kind() != @rtps.SedpEndpointKind::Subscription {
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
    reader_prefix: Some(subscription.endpoint_guid().prefix()),
  })
}

///|
/// Add the remote participant destination when this writer targets a discovered endpoint.
fn DataWriter::message_for_reader(
  self : DataWriter,
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
  self.next_sequence_number
}

///|
/// Send one best-effort serialized payload and advance its sequence number.
pub async fn DataWriter::write(
  self : DataWriter,
  serialized_payload : Bytes,
) -> Result[Unit, String] {
  let sequence_number = self.next_sequence_number
  let data = @rtps.DataSubmessage::new(
    self.reader_id,
    self.writer_id,
    sequence_number,
    serialized_payload,
  )
  let result = if reliable_writer_data_fits_datagram(data) {
    for destination in self.destinations {
      match
        self.socket.send_message(
          self.message_for_reader(
            data.to_message(self.guid_prefix, self.vendor_id),
          ),
          destination,
        ) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    }
    Ok(())
  } else {
    let fragments = match reliable_writer_fragment_data(data) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    for fragment in fragments {
      for destination in self.destinations {
        match
          self.socket.send_message(
            self.message_for_reader(
              fragment.to_message(self.guid_prefix, self.vendor_id),
            ),
            destination,
          ) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      }
    }
    Ok(())
  }
  match result {
    Ok(_) => {
      self.next_sequence_number = sequence_number + 1L
      Ok(())
    }
    Err(message) => Err(message)
  }
}

///|
/// Close the writer's underlying UDP socket.
pub fn DataWriter::close(self : DataWriter) -> Unit {
  self.socket.close()
}
