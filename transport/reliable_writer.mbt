///|
/// A minimal reliable RTPS DataWriter with an in-memory history.
///
/// The caller drives HEARTBEAT transmission and passes decoded ACKNACKs to
/// `handle_acknack`. This keeps scheduling and socket receive ownership in the
/// application while providing the wire-level retransmission primitive.
pub struct ReliableDataWriter {
  socket : Udp
  guid_prefix : @rtps.GuidPrefix
  vendor_id : @rtps.VendorId
  reader_id : @rtps.EntityId
  writer_id : @rtps.EntityId
  destination : @socket.Addr
  mut next_sequence_number : Int64
  mut next_heartbeat_count : UInt
  history : Array[@rtps.DataSubmessage]
}

///|
/// Create a reliable writer whose history is retained for retransmission.
pub fn ReliableDataWriter::new(
  socket : Udp,
  guid_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  reader_id : @rtps.EntityId,
  writer_id : @rtps.EntityId,
  destination : @socket.Addr,
  first_sequence_number : Int64,
) -> Result[ReliableDataWriter, String] {
  if first_sequence_number < 1L {
    return Err("an RTPS DATA sequence number must be positive")
  }
  Ok({
    socket,
    guid_prefix,
    vendor_id,
    reader_id,
    writer_id,
    destination,
    next_sequence_number: first_sequence_number,
    next_heartbeat_count: 1U,
    history: [],
  })
}

///|
pub fn ReliableDataWriter::next_sequence_number(
  self : ReliableDataWriter,
) -> Int64 {
  self.next_sequence_number
}

///|
pub fn ReliableDataWriter::next_heartbeat_count(
  self : ReliableDataWriter,
) -> UInt {
  self.next_heartbeat_count
}

///|
/// Return the number of samples retained for retransmission.
pub fn ReliableDataWriter::history_length(self : ReliableDataWriter) -> Int {
  self.history.length()
}

///|
/// Send one sample and retain it in the reliable writer history.
pub async fn ReliableDataWriter::write(
  self : ReliableDataWriter,
  serialized_payload : Bytes,
) -> Result[Unit, String] {
  let sequence_number = self.next_sequence_number
  let data = @rtps.DataSubmessage::new(
    self.reader_id,
    self.writer_id,
    sequence_number,
    serialized_payload,
  )
  match
    self.socket.send_data(
      data,
      self.guid_prefix,
      self.vendor_id,
      self.destination,
    ) {
    Ok(_) => {
      self.history.push(data)
      self.next_sequence_number = sequence_number + 1L
      Ok(())
    }
    Err(message) => Err(message)
  }
}

///|
/// Announce the currently retained sequence range to the remote reader.
pub async fn ReliableDataWriter::send_heartbeat(
  self : ReliableDataWriter,
) -> Result[Unit, String] {
  if self.history.length() == 0 {
    return Err("cannot send a HEARTBEAT before the first sample")
  }
  let first_sequence_number = self.history[0].writer_sequence_number()
  let last_sequence_number = self.history[self.history.length() - 1].writer_sequence_number()
  let heartbeat = match
    @rtps.HeartbeatSubmessage::new(
      self.reader_id,
      self.writer_id,
      first_sequence_number,
      last_sequence_number,
      self.next_heartbeat_count,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match
    self.socket.send_heartbeat(
      heartbeat,
      self.guid_prefix,
      self.vendor_id,
      self.destination,
    ) {
    Ok(_) => {
      self.next_heartbeat_count += 1U
      Ok(())
    }
    Err(message) => Err(message)
  }
}

///|
fn reliable_bitmap_contains(bitmap : Array[UInt], offset : Int) -> Bool {
  let word_index = offset / 32
  let bit_index = offset % 32
  let mask : UInt = 0x80000000U >> bit_index
  (bitmap[word_index] & mask) != 0U
}

///|
/// Retransmit the sequence numbers selected by an ACKNACK bitmap.
pub async fn ReliableDataWriter::handle_acknack(
  self : ReliableDataWriter,
  acknack : @rtps.AckNackSubmessage,
) -> Result[Unit, String] {
  if acknack.writer_id() != self.writer_id {
    return Err("the ACKNACK targets a different RTPS writer")
  }
  if acknack.reader_id() != self.reader_id {
    return Err("the ACKNACK targets a different RTPS reader")
  }
  let bitmap = acknack.bitmap()
  let num_bits = acknack.num_bits().reinterpret_as_int()
  for offset in 0..<num_bits {
    if !reliable_bitmap_contains(bitmap, offset) {
      continue
    }
    let requested_sequence = acknack.bitmap_base() + offset.to_int64()
    for sample in self.history {
      if sample.writer_sequence_number() != requested_sequence {
        continue
      }
      match
        self.socket.send_data(
          sample,
          self.guid_prefix,
          self.vendor_id,
          self.destination,
        ) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    }
  }
  Ok(())
}

///|
/// Close the reliable writer's underlying UDP socket.
pub fn ReliableDataWriter::close(self : ReliableDataWriter) -> Unit {
  self.socket.close()
}
