///|
priv struct DiscoveryEndpointSequence {
  endpoint_guid : @core.Guid
  mut sequence_number : Int64
}

///|
/// Locate or create reliable receive state for one remote SEDP writer.
fn DiscoveryEngine::sedp_reader_index(
  self : DiscoveryEngine,
  writer_prefix : @core.GuidPrefix,
  writer_id : @core.EntityId,
) -> Result[Int32, String] {
  for index in 0..<self.sedp_readers.length() {
    let reader = self.sedp_readers[index]
    if reader.writer_prefix == writer_prefix && reader.writer_id == writer_id {
      return Ok(index)
    }
  }
  if !self.can_add_discovery_reader() {
    return Err("discovery receive writer limit reached")
  }
  let kind = match SedpEndpointKind::from_builtin_writer_id(writer_id) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  self.sedp_readers.push({
    writer_prefix,
    writer_id,
    reader: @core.ReliableDataReader::new(kind.builtin_reader_id(), writer_id),
    endpoint_sequences: [],
    expires_at: None,
  })
  Ok(self.sedp_readers.length() - 1)
}

///|
/// Locate or create fragment assembly state for one remote SPDP writer.
fn DiscoveryEngine::spdp_fragment_reader_index(
  self : DiscoveryEngine,
  writer_prefix : @core.GuidPrefix,
  now_ms : Int64,
) -> Result[Int32, String] {
  for index in 0..<self.spdp_fragment_readers.length() {
    if self.spdp_fragment_readers[index].writer_prefix == writer_prefix {
      return Ok(index)
    }
  }
  if !self.can_add_discovery_reader() {
    return Err("discovery receive writer limit reached")
  }
  self.spdp_fragment_readers.push({
    writer_prefix,
    writer_id: self.writer_id,
    reader: @core.ReliableDataReader::new(self.reader_id, self.writer_id),
    endpoint_sequences: [],
    expires_at: Some(now_ms + DISCOVERY_SPDP_FRAGMENT_LIFETIME_MS),
  })
  Ok(self.spdp_fragment_readers.length() - 1)
}

///|
/// Drop reliability state for one remote participant incarnation.
fn DiscoveryEngine::forget_remote_participant_reliability(
  self : DiscoveryEngine,
  participant_prefix : @core.GuidPrefix,
) -> Unit {
  self.sedp_readers = self.sedp_readers.filter(fn(reader) {
    reader.writer_prefix != participant_prefix
  })
  self.spdp_fragment_readers = self.spdp_fragment_readers.filter(fn(reader) {
    reader.writer_prefix != participant_prefix
  })
  self.sender.forget_remote_participant(participant_prefix)
}

///|
/// Record one SPDP sequence and classify the announcement.
///
/// A retransmitted sequence means the peer recreated its view of this
/// participant (for example after dropping it), so its fresh EDP readers
/// restart their ACKNACK/NACK_FRAG counts. A lower sequence means the peer
/// restarted with the same GUID prefix, so both its readers and writers start
/// over and this side must also drop the stale receive high-water marks.
fn DiscoveryEngine::record_spdp_writer_sequence(
  self : DiscoveryEngine,
  writer_prefix : @core.GuidPrefix,
  sequence_number : Int64,
) -> DiscoverySpdpAnnouncement {
  for entry in self.spdp_writer_sequences {
    if entry.writer_prefix == writer_prefix {
      if sequence_number == entry.sequence_number {
        return Retransmitted
      }
      let restarted = sequence_number < entry.sequence_number
      entry.sequence_number = sequence_number
      return if restarted { Restarted } else { New }
    }
  }
  self.spdp_writer_sequences.push({ writer_prefix, sequence_number, })
  New
}

///|
/// Drop reliability receive state after a participant disappears.
fn DiscoveryEngine::forget_remote_participant(
  self : DiscoveryEngine,
  participant_guid : @core.Guid,
) -> Unit {
  self.forget_remote_participant_reliability(participant_guid.prefix())
  self.spdp_writer_sequences = self.spdp_writer_sequences.filter(fn(entry) {
    entry.writer_prefix != participant_guid.prefix()
  })
}

///|
fn DiscoveryEngine::acknowledgement_destination(
  self : DiscoveryEngine,
  prefix : @core.GuidPrefix,
  source : @core.Locator,
) -> @core.Locator {
  for participant in self.spdp.participants() {
    if participant.participant_guid().prefix() == prefix {
      for locator in participant.metatraffic_unicast_locators() {
        if locator.kind() == self.sender.destination.kind() {
          return locator
        }
      }
    }
  }
  source
}

///|
/// Reject duplicate DATA while retaining every new sequence for reliable ACKs.
/// Fragment completion already records its sequence in the shared reader.
fn DiscoveryEngine::record_sedp_data(
  self : DiscoveryEngine,
  writer_prefix : @core.GuidPrefix,
  data : @core.DataSubmessage,
  fragment_complete : Bool,
) -> Bool {
  let index = match self.sedp_reader_index(writer_prefix, data.writer_id()) {
    Ok(value) => value
    Err(_) => return false
  }
  let reader = self.sedp_readers[index].reader
  if fragment_complete {
    return true
  }
  if reader.has_received_sequence(data.writer_sequence_number()) {
    return false
  }
  reader.accept_data(data) is Ok(_)
}

///|
/// Keep endpoint state monotonic without dropping older samples from ACK state.
fn DiscoveryEngine::advance_endpoint_sequence(
  self : DiscoveryEngine,
  writer_prefix : @core.GuidPrefix,
  data : @core.DataSubmessage,
  endpoint_guid : @core.Guid,
) -> Bool {
  let index = match self.sedp_reader_index(writer_prefix, data.writer_id()) {
    Ok(value) => value
    Err(_) => return false
  }
  let sequences = self.sedp_readers[index].endpoint_sequences
  for endpoint in sequences {
    if endpoint.endpoint_guid == endpoint_guid {
      if data.writer_sequence_number() <= endpoint.sequence_number {
        return false
      }
      endpoint.sequence_number = data.writer_sequence_number()
      return true
    }
  }
  sequences.push({
    endpoint_guid,
    sequence_number: data.writer_sequence_number(),
  })
  true
}
