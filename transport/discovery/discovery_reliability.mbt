///|
/// Acknowledge a reliable SEDP HEARTBEAT on the session's send socket.
async fn DiscoverySession::acknowledge_sedp_heartbeat(
  self : DiscoverySession,
  writer_prefix : @rtps.GuidPrefix,
  heartbeat : @rtps.HeartbeatSubmessage,
  source : @socket.Addr,
) -> Result[Unit, String] {
  let index = match
    self.sedp_reader_index(writer_prefix, heartbeat.writer_id()) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let acknacks = match
    self.sedp_readers[index].reader.acknacks_for_heartbeat(heartbeat) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let destination = self.acknowledgement_destination(writer_prefix, source)
  for index in 0..<acknacks.length() {
    let acknack = if index + 1 == acknacks.length() &&
      !discovery_acknack_has_requests(acknacks[index]) {
      acknacks[index].with_final()
    } else {
      acknacks[index]
    }
    match
      self.socket.send_message(
        acknack
        .to_message(
          self.participant.participant_guid().prefix(),
          self.participant.vendor_id(),
        )
        .with_destination_guid_prefix(writer_prefix),
        destination,
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(())
}

///|
/// Send NACK_FRAG requests for missing fragments in a reliable SEDP sample.
async fn DiscoverySession::acknowledge_sedp_heartbeat_frag(
  self : DiscoverySession,
  writer_prefix : @rtps.GuidPrefix,
  heartbeat : @rtps.HeartbeatFragSubmessage,
  source : @socket.Addr,
) -> Result[Unit, String] {
  let kind = match
    @rtps.SedpEndpointKind::from_builtin_writer_id(heartbeat.writer_id()) {
    Ok(value) => value
    Err(_) => return Ok(())
  }
  if heartbeat.reader_id() != kind.builtin_reader_id() &&
    heartbeat.reader_id() != @rtps.EntityId::unknown() {
    return Ok(())
  }
  let index = match
    self.sedp_reader_index(writer_prefix, heartbeat.writer_id()) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let nackfrags = match
    self.sedp_readers[index].reader.nackfrags_for_heartbeat_frag(heartbeat) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let destination = self.acknowledgement_destination(writer_prefix, source)
  for nackfrag in nackfrags {
    match
      self.socket.send_message(
        nackfrag
        .to_message(
          self.participant.participant_guid().prefix(),
          self.participant.vendor_id(),
        )
        .with_destination_guid_prefix(writer_prefix),
        destination,
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(())
}

///|
fn discovery_acknack_bitmap_contains(
  bitmap : Array[UInt32],
  offset : Int32,
) -> Bool {
  let word_index = offset / 32
  let bit_index = offset % 32
  (bitmap[word_index] & (0x80000000U >> bit_index)) != 0U
}

///|
/// Return whether an ACKNACK requests any missing samples.
fn discovery_acknack_has_requests(acknack : @rtps.AckNackSubmessage) -> Bool {
  for offset in 0..<acknack.num_bits().reinterpret_as_int() {
    if discovery_acknack_bitmap_contains(acknack.bitmap(), offset) {
      return true
    }
  }
  false
}

///|
/// Retransmit local SEDP samples requested by one remote ACKNACK.
async fn DiscoverySession::retransmit_sedp_acknack(
  self : DiscoverySession,
  reader_prefix : @rtps.GuidPrefix,
  acknack : @rtps.AckNackSubmessage,
  source : @socket.Addr,
) -> Result[Unit, String] {
  let kind = match
    @rtps.SedpEndpointKind::from_builtin_writer_id(acknack.writer_id()) {
    Ok(value) => value
    Err(_) => return Ok(())
  }
  if acknack.reader_id() != kind.builtin_reader_id() &&
    acknack.reader_id() != @rtps.EntityId::unknown() {
    return Ok(())
  }
  let writer_index = self.sedp_writer_index(kind)
  let bitmap = acknack.bitmap()
  let num_bits = acknack.num_bits().reinterpret_as_int()
  for offset in 0..<num_bits {
    if !discovery_acknack_bitmap_contains(bitmap, offset) {
      continue
    }
    let sequence_number = acknack.bitmap_base() + offset.to_int64()
    for sample in self.sedp_writers[writer_index].samples {
      if sample.writer_sequence_number() != sequence_number {
        continue
      }
      match
        self.socket.send_message(
          sample
          .to_message(
            self.participant.participant_guid().prefix(),
            self.participant.vendor_id(),
          )
          .with_destination_guid_prefix(reader_prefix),
          source,
        ) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    }
  }
  Ok(())
}
