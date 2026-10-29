///|
/// Dispatch one parsed SEDP sample as a publication, subscription, or removal.
fn DiscoveryEngine::dispatch_sedp_data(
  self : DiscoveryEngine,
  events : Array[DiscoveryEvent],
  writer_prefix : @core.GuidPrefix,
  kind : SedpEndpointKind,
  data : @core.DataSubmessage,
  fragment_complete : Bool,
) -> Unit {
  if !self.record_sedp_data(writer_prefix, data, fragment_complete) {
    return
  }
  let status = match data.status_info() {
    Ok(value) => value
    Err(_) => return
  }
  match status {
    Some(value) if (
        value & (@core.STATUS_INFO_DISPOSED | @core.STATUS_INFO_UNREGISTERED)
      ) !=
      0U => {
      if (data.flags() & @core.DATA_FLAG_KEY) == 0 {
        return
      }
      match SedpEndpointData::endpoint_guid_from_key_data(data) {
        Ok(endpoint_guid) =>
          if self.advance_endpoint_sequence(writer_prefix, data, endpoint_guid) {
            events.push(EndpointRemoved(kind, endpoint_guid))
          }
        Err(_) => ()
      }
    }
    _ =>
      match SedpEndpointData::from_data_submessage(kind, data) {
        Ok(endpoint) => {
          if !self.advance_endpoint_sequence(
              writer_prefix,
              data,
              endpoint.endpoint_guid(),
            ) {
            return
          }
          events.push(
            match kind {
              Publication => Publication(endpoint)
              Subscription => Subscription(endpoint)
            },
          )
        }
        Err(_) => ()
      }
  }
}

///|
/// Dispatch a parsed SPDP announcement or participant removal.
fn DiscoveryEngine::dispatch_spdp_data(
  self : DiscoveryEngine,
  events : Array[DiscoveryEvent],
  data : @core.DataSubmessage,
  now_ms : Int64,
) -> Unit {
  for event in self.spdp.receive(data, now_ms) {
    events.push(self.map_participant_event(event))
  }
}

///|
/// Remember a received SEDP GAP for later ACKNACK generation.
fn DiscoveryEngine::record_sedp_gap(
  self : DiscoveryEngine,
  writer_prefix : @core.GuidPrefix,
  gap : @core.GapSubmessage,
) -> Unit {
  let index = match self.sedp_reader_index(writer_prefix, gap.writer_id()) {
    Ok(value) => value
    Err(_) => return
  }
  ignore(self.sedp_readers[index].reader.accept_gap(gap))
}

///|
/// Apply reliability cleanup while mapping the pure participant event.
fn DiscoveryEngine::map_participant_event(
  self : DiscoveryEngine,
  event : ParticipantEvent,
) -> DiscoveryEvent {
  match event {
    Participant(participant) => Participant(participant)
    ParticipantRemoved(guid) => {
      self.forget_remote_participant(guid)
      ParticipantRemoved(guid)
    }
  }
}
