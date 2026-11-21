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
///
/// A retransmitted announcement means the peer recreated its view of this
/// participant, so replay the retained SEDP samples and accept control counts
/// from the peer's fresh EDP readers. A lower sequence means the peer restarted
/// with the same prefix; its SEDP writers restarted too.
fn DiscoveryEngine::dispatch_spdp_data(
  self : DiscoveryEngine,
  events : Array[DiscoveryEvent],
  outgoing : Array[DiscoveryOutput],
  writer_prefix : @core.GuidPrefix,
  data : @core.DataSubmessage,
  now_ms : Int64,
) -> Unit {
  let participant_events = self.spdp.receive(data, now_ms)
  if participant_events.length() == 0 {
    return
  }
  let announcement = self.record_spdp_writer_sequence(
    writer_prefix,
    data.writer_sequence_number(),
  )
  match announcement {
    New => ()
    Retransmitted => self.sender.forget_remote_participant(writer_prefix)
    Restarted => self.forget_remote_participant_reliability(writer_prefix)
  }
  let replayed = match announcement {
    New => false
    Retransmitted | Restarted => true
  }
  for event in participant_events {
    if replayed {
      match event {
        Participant(participant) =>
          if participant.participant_guid().prefix() == writer_prefix {
            match self.replay_sedp(participant) {
              Ok(outputs) =>
                for output in outputs {
                  outgoing.push(output)
                }
              Err(_) => ()
            }
          }
        ParticipantRemoved(_) => ()
      }
    }
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
