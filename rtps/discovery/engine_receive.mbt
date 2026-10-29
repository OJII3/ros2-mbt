///|
/// Decode one RTPS message into its SPDP/SEDP discovery events.
pub fn DiscoveryEngine::receive(
  self : DiscoveryEngine,
  message : @core.Message,
  source : @core.Locator,
  now_ms : Int64,
) -> Result[DiscoveryEffects, String] {
  let effects = self.advance(now_ms)
  let events = effects.events
  let outgoing = effects.outgoing
  let mut addressed = true
  for submessage in message.submessages() {
    if submessage.id() == InfoDestination {
      match @core.InfoDestinationSubmessage::from_submessage(submessage) {
        Ok(info) =>
          addressed = info.guid_prefix() ==
            self.participant.participant_guid().prefix() ||
            discovery_guid_prefix_is_unknown(info.guid_prefix())
        Err(_) => addressed = false
      }
      continue
    }
    if !addressed {
      continue
    }
    match submessage.id() {
      Data => {
        if (submessage.flags() & (@core.DATA_FLAG_DATA | @core.DATA_FLAG_KEY)) ==
          0x00 {
          continue
        }
        let data = match @core.DataSubmessage::from_submessage(submessage) {
          Ok(value) => value
          Err(_) => continue
        }
        match SedpEndpointKind::from_builtin_writer_id(data.writer_id()) {
          Ok(kind) => {
            if data.reader_id() != kind.builtin_reader_id() &&
              data.reader_id() != @core.EntityId::unknown() {
              continue
            }
            self.dispatch_sedp_data(
              events,
              message.header().guid_prefix(),
              kind,
              data,
              false,
            )
          }
          Err(_) => {
            if data.writer_id() != self.writer_id ||
              (
                data.reader_id() != self.reader_id &&
                data.reader_id() != @core.EntityId::unknown()
              ) {
              continue
            }
            self.dispatch_spdp_data(events, data, now_ms)
          }
        }
      }
      DataFrag => {
        let fragment = match
          @core.DataFragSubmessage::from_submessage(submessage) {
          Ok(value) => value
          Err(_) => continue
        }
        // Reject claimed sizes and aggregate allocations before creating a reader.
        if !self.can_receive_discovery_fragment(
            message.header().guid_prefix(),
            fragment,
          ) {
          continue
        }
        match SedpEndpointKind::from_builtin_writer_id(fragment.writer_id()) {
          Ok(kind) => {
            if fragment.reader_id() != kind.builtin_reader_id() &&
              fragment.reader_id() != @core.EntityId::unknown() {
              continue
            }
            let reader_index = match
              self.sedp_reader_index(
                message.header().guid_prefix(),
                fragment.writer_id(),
              ) {
              Ok(value) => value
              Err(_) => continue
            }
            let data = match
              self.sedp_readers[reader_index].reader.accept_data_frag(fragment) {
              Ok(value) => value
              Err(_) => continue
            }
            match data {
              Some(data) =>
                self.dispatch_sedp_data(
                  events,
                  message.header().guid_prefix(),
                  kind,
                  data,
                  true,
                )
              None => ()
            }
          }
          Err(_) => {
            if fragment.writer_id() != self.writer_id ||
              (
                fragment.reader_id() != self.reader_id &&
                fragment.reader_id() != @core.EntityId::unknown()
              ) {
              continue
            }
            let reader_index = match
              self.spdp_fragment_reader_index(
                message.header().guid_prefix(),
                now_ms,
              ) {
              Ok(value) => value
              Err(_) => continue
            }
            let data = match
              self.spdp_fragment_readers[reader_index].reader.accept_best_effort_fragment(
                fragment,
              ) {
              Ok(value) => value
              Err(_) => continue
            }
            match data {
              Some(data) => self.dispatch_spdp_data(events, data, now_ms)
              None => ()
            }
          }
        }
      }
      Heartbeat => {
        let heartbeat = match
          @core.HeartbeatSubmessage::from_submessage(submessage) {
          Ok(value) => value
          Err(_) => continue
        }
        if SedpEndpointKind::from_builtin_writer_id(heartbeat.writer_id())
          is Ok(_) {
          let kind = match
            SedpEndpointKind::from_builtin_writer_id(heartbeat.writer_id()) {
            Ok(value) => value
            Err(_) => continue
          }
          if heartbeat.reader_id() != kind.builtin_reader_id() &&
            heartbeat.reader_id() != @core.EntityId::unknown() {
            continue
          }
          match
            self.acknowledge_sedp_heartbeat(
              message.header().guid_prefix(),
              heartbeat,
              source,
              outgoing,
            ) {
            Ok(_) => ()
            Err(_) => continue
          }
        }
      }
      HeartbeatFrag => {
        let heartbeat = match
          @core.HeartbeatFragSubmessage::from_submessage(submessage) {
          Ok(value) => value
          Err(_) => continue
        }
        match
          self.acknowledge_sedp_heartbeat_frag(
            message.header().guid_prefix(),
            heartbeat,
            source,
            outgoing,
          ) {
          Ok(_) => ()
          Err(_) => continue
        }
      }
      Gap => {
        let gap = match @core.GapSubmessage::from_submessage(submessage) {
          Ok(value) => value
          Err(_) => continue
        }
        if SedpEndpointKind::from_builtin_writer_id(gap.writer_id()) is Ok(_) {
          let kind = match
            SedpEndpointKind::from_builtin_writer_id(gap.writer_id()) {
            Ok(value) => value
            Err(_) => continue
          }
          if gap.reader_id() != kind.builtin_reader_id() &&
            gap.reader_id() != @core.EntityId::unknown() {
            continue
          }
          self.record_sedp_gap(message.header().guid_prefix(), gap)
        }
      }
      AckNack => {
        let acknack = match
          @core.AckNackSubmessage::from_submessage(submessage) {
          Ok(value) => value
          Err(_) => continue
        }
        match
          self.sender.retransmit_acknack(
            message.header().guid_prefix(),
            acknack,
            self.acknowledgement_destination(
              message.header().guid_prefix(),
              source,
            ),
          ) {
          Ok(outputs) =>
            for output in outputs {
              outgoing.push(output)
            }
          Err(_) => continue
        }
      }
      NackFrag => {
        let nackfrag = match
          @core.NackFragSubmessage::from_submessage(submessage) {
          Ok(value) => value
          Err(_) => continue
        }
        match
          self.sender.retransmit_nackfrag(
            message.header().guid_prefix(),
            nackfrag,
            self.acknowledgement_destination(
              message.header().guid_prefix(),
              source,
            ),
          ) {
          Ok(outputs) =>
            for output in outputs {
              outgoing.push(output)
            }
          Err(_) => continue
        }
      }
      _ => ()
    }
  }
  Ok(effects)
}
