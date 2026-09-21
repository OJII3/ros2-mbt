///|
/// Dispatch one parsed SEDP sample as a publication, subscription, or removal.
fn DiscoverySession::dispatch_sedp_data(
  self : DiscoverySession,
  events : Array[DiscoveryEvent],
  writer_prefix : @rtps.GuidPrefix,
  kind : @rtps.SedpEndpointKind,
  data : @rtps.DataSubmessage,
) -> Unit {
  self.record_sedp_data(writer_prefix, data)
  let status = match data.status_info() {
    Ok(value) => value
    Err(_) => return
  }
  match status {
    Some(value) if (
        value & (@rtps.STATUS_INFO_DISPOSED | @rtps.STATUS_INFO_UNREGISTERED)
      ) !=
      0U => {
      if (data.flags() & @rtps.DATA_FLAG_KEY) == 0 {
        return
      }
      match @rtps.SedpEndpointData::endpoint_guid_from_key_data(data) {
        Ok(endpoint_guid) =>
          events.push(DiscoveryEvent::EndpointRemoved(kind, endpoint_guid))
        Err(_) => ()
      }
    }
    _ =>
      match @rtps.SedpEndpointData::from_data_submessage(kind, data) {
        Ok(endpoint) =>
          events.push(
            match kind {
              @rtps.SedpEndpointKind::Publication =>
                DiscoveryEvent::Publication(endpoint)
              @rtps.SedpEndpointKind::Subscription =>
                DiscoveryEvent::Subscription(endpoint)
            },
          )
        Err(_) => ()
      }
  }
}

///|
/// Dispatch a parsed SPDP announcement or participant removal.
fn DiscoverySession::dispatch_spdp_data(
  self : DiscoverySession,
  events : Array[DiscoveryEvent],
  data : @rtps.DataSubmessage,
) -> Unit {
  let status = match data.status_info() {
    Ok(value) => value
    Err(_) => return
  }
  match status {
    Some(value) if (
        value & (@rtps.STATUS_INFO_DISPOSED | @rtps.STATUS_INFO_UNREGISTERED)
      ) !=
      0U => {
      if (data.flags() & @rtps.DATA_FLAG_KEY) == 0 {
        return
      }
      match @rtps.SpdpParticipantData::participant_guid_from_key_data(data) {
        Ok(participant_guid) => {
          self.forget_remote_participant(participant_guid)
          events.push(DiscoveryEvent::ParticipantRemoved(participant_guid))
        }
        Err(_) => ()
      }
    }
    _ =>
      match
        @rtps.SpdpParticipantData::from_data_submessage_with_default_domain(
          data,
          self.participant.domain_id(),
        ) {
        Ok(participant) =>
          if participant.domain_id() == self.participant.domain_id() {
            self.remember_remote_participant(participant)
            events.push(DiscoveryEvent::Participant(participant))
          }
        Err(_) => ()
      }
  }
}

///|
/// Remember a received SEDP GAP for later ACKNACK generation.
fn DiscoverySession::record_sedp_gap(
  self : DiscoverySession,
  writer_prefix : @rtps.GuidPrefix,
  gap : @rtps.GapSubmessage,
) -> Unit {
  let index = match self.sedp_reader_index(writer_prefix, gap.writer_id()) {
    Ok(value) => value
    Err(_) => return
  }
  ignore(self.sedp_readers[index].reader.accept_gap(gap))
}

