///|
/// Dispatch one parsed SEDP sample as a publication, subscription, or removal.
fn DiscoverySession::dispatch_sedp_data(
  self : DiscoverySession,
  events : Array[@wire.DiscoveryEvent],
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
        Ok(endpoint_guid) => events.push(EndpointRemoved(kind, endpoint_guid))
        Err(_) => ()
      }
    }
    _ =>
      match @rtps.SedpEndpointData::from_data_submessage(kind, data) {
        Ok(endpoint) =>
          events.push(
            match kind {
              Publication => Publication(endpoint)
              Subscription => Subscription(endpoint)
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
  events : Array[@wire.DiscoveryEvent],
  data : @rtps.DataSubmessage,
) -> Unit {
  let now_ms = self.clock.now_ms()
  self.queue_expired_participants_at(now_ms)
  for event in self.spdp.receive(data, now_ms) {
    events.push(self.map_participant_event(event))
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

///|
/// Apply transport cleanup while mapping the pure participant event.
fn DiscoverySession::map_participant_event(
  self : DiscoverySession,
  event : @participant_discovery.ParticipantEvent,
) -> @wire.DiscoveryEvent {
  match event {
    Participant(participant) => Participant(participant)
    ParticipantRemoved(guid) => {
      self.forget_remote_participant(guid)
      ParticipantRemoved(guid)
    }
  }
}

///|
fn DiscoverySession::queue_expired_participants(
  self : DiscoverySession,
) -> Unit {
  self.queue_expired_participants_at(self.clock.now_ms())
}

///|
fn DiscoverySession::queue_expired_participants_at(
  self : DiscoverySession,
  now_ms : Int64,
) -> Unit {
  for event in self.spdp.expire(now_ms) {
    self.pending_events.push(
      (self.map_participant_event(event), @socket.Addr::new(0, 0)),
    )
  }
}
