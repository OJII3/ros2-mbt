///|
/// Produce ACKNACK effects for a reliable SEDP HEARTBEAT.
fn DiscoveryEngine::acknowledge_sedp_heartbeat(
  self : DiscoveryEngine,
  writer_prefix : @core.GuidPrefix,
  heartbeat : @core.HeartbeatSubmessage,
  source : @core.Locator,
  outgoing : Array[DiscoveryOutput],
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
    outgoing.push({
      message: acknack
      .to_message(
        self.participant.participant_guid().prefix(),
        self.participant.vendor_id(),
      )
      .with_destination_guid_prefix(writer_prefix),
      destination,
    })
  }
  Ok(())
}

///|
/// Send NACK_FRAG requests for missing fragments in a reliable SEDP sample.
fn DiscoveryEngine::acknowledge_sedp_heartbeat_frag(
  self : DiscoveryEngine,
  writer_prefix : @core.GuidPrefix,
  heartbeat : @core.HeartbeatFragSubmessage,
  source : @core.Locator,
  outgoing : Array[DiscoveryOutput],
) -> Result[Unit, String] {
  // Bound NACK_FRAG response generation even before any DATA_FRAG arrives.
  if heartbeat.last_fragment_number() >
    DISCOVERY_MAX_FRAGMENTS.reinterpret_as_uint() {
    return Ok(())
  }
  let kind = match
    SedpEndpointKind::from_builtin_writer_id(heartbeat.writer_id()) {
    Ok(value) => value
    Err(_) => return Ok(())
  }
  if heartbeat.reader_id() != kind.builtin_reader_id() &&
    heartbeat.reader_id() != @core.EntityId::unknown() {
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
    outgoing.push({
      message: nackfrag
      .to_message(
        self.participant.participant_guid().prefix(),
        self.participant.vendor_id(),
      )
      .with_destination_guid_prefix(writer_prefix),
      destination,
    })
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
fn discovery_acknack_has_requests(acknack : @core.AckNackSubmessage) -> Bool {
  for offset in 0..<acknack.num_bits().reinterpret_as_int() {
    if discovery_acknack_bitmap_contains(acknack.bitmap(), offset) {
      return true
    }
  }
  false
}
