///|
/// Decode one RTPS message into its SPDP/SEDP discovery events.
async fn DiscoverySession::decode_message(
  self : DiscoverySession,
  message : @rtps.Message,
  source : @socket.Addr,
  socket_index : Int,
) -> Result[Array[DiscoveryEvent], String] {
  match message.destination_guid_prefix() {
    Ok(Some(destination)) if destination !=
      self.participant.participant_guid().prefix() &&
      !transport_guid_prefix_is_unknown(destination) => return Ok([])
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let events : Array[DiscoveryEvent] = []
  for submessage in message.submessages() {
    match submessage.id() {
      @rtps.SubmessageId::Data => {
        if (submessage.flags() & (@rtps.DATA_FLAG_DATA | @rtps.DATA_FLAG_KEY)) ==
          0x00 {
          continue
        }
        let data = match @rtps.DataSubmessage::from_submessage(submessage) {
          Ok(value) => value
          Err(_) => continue
        }
        match @rtps.SedpEndpointKind::from_builtin_writer_id(data.writer_id()) {
          Ok(kind) => {
            if data.reader_id() != kind.builtin_reader_id() &&
              data.reader_id() != @rtps.EntityId::unknown() {
              continue
            }
            self.dispatch_sedp_data(
              events,
              message.header().guid_prefix(),
              kind,
              data,
            )
          }
          Err(_) => {
            if data.writer_id() != self.writer_id ||
              (
                data.reader_id() != self.reader_id &&
                data.reader_id() != @rtps.EntityId::unknown()
              ) {
              continue
            }
            self.dispatch_spdp_data(events, data)
          }
        }
      }
      @rtps.SubmessageId::DataFrag => {
        let fragment = match
          @rtps.DataFragSubmessage::from_submessage(submessage) {
          Ok(value) => value
          Err(_) => continue
        }
        match
          @rtps.SedpEndpointKind::from_builtin_writer_id(fragment.writer_id()) {
          Ok(kind) => {
            if fragment.reader_id() != kind.builtin_reader_id() &&
              fragment.reader_id() != @rtps.EntityId::unknown() {
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
                )
              None => ()
            }
          }
          Err(_) => {
            if fragment.writer_id() != self.writer_id ||
              (
                fragment.reader_id() != self.reader_id &&
                fragment.reader_id() != @rtps.EntityId::unknown()
              ) {
              continue
            }
            let reader_index = self.spdp_fragment_reader_index(
              message.header().guid_prefix(),
            )
            let data = match
              self.spdp_fragment_readers[reader_index].reader.accept_data_frag(
                fragment,
              ) {
              Ok(value) => value
              Err(_) => continue
            }
            match data {
              Some(data) => self.dispatch_spdp_data(events, data)
              None => ()
            }
          }
        }
      }
      @rtps.SubmessageId::Heartbeat => {
        let heartbeat = match
          @rtps.HeartbeatSubmessage::from_submessage(submessage) {
          Ok(value) => value
          Err(_) => continue
        }
        if @rtps.SedpEndpointKind::from_builtin_writer_id(heartbeat.writer_id())
          is Ok(_) {
          let kind = match
            @rtps.SedpEndpointKind::from_builtin_writer_id(
              heartbeat.writer_id(),
            ) {
            Ok(value) => value
            Err(_) => continue
          }
          if heartbeat.reader_id() != kind.builtin_reader_id() &&
            heartbeat.reader_id() != @rtps.EntityId::unknown() {
            continue
          }
          match
            self.acknowledge_sedp_heartbeat(
              socket_index,
              message.header().guid_prefix(),
              heartbeat,
              source,
            ) {
            Ok(_) => ()
            Err(message) => return Err(message)
          }
        }
      }
      @rtps.SubmessageId::HeartbeatFrag => {
        let heartbeat = match
          @rtps.HeartbeatFragSubmessage::from_submessage(submessage) {
          Ok(value) => value
          Err(_) => continue
        }
        match
          self.acknowledge_sedp_heartbeat_frag(
            socket_index,
            message.header().guid_prefix(),
            heartbeat,
            source,
          ) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      }
      @rtps.SubmessageId::Gap => {
        let gap = match @rtps.GapSubmessage::from_submessage(submessage) {
          Ok(value) => value
          Err(_) => continue
        }
        if @rtps.SedpEndpointKind::from_builtin_writer_id(gap.writer_id())
          is Ok(_) {
          let kind = match
            @rtps.SedpEndpointKind::from_builtin_writer_id(gap.writer_id()) {
            Ok(value) => value
            Err(_) => continue
          }
          if gap.reader_id() != kind.builtin_reader_id() &&
            gap.reader_id() != @rtps.EntityId::unknown() {
            continue
          }
          self.record_sedp_gap(message.header().guid_prefix(), gap)
        }
      }
      @rtps.SubmessageId::AckNack => {
        let acknack = match
          @rtps.AckNackSubmessage::from_submessage(submessage) {
          Ok(value) => value
          Err(_) => continue
        }
        match
          self.retransmit_sedp_acknack(
            socket_index,
            message.header().guid_prefix(),
            acknack,
            source,
          ) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      }
      _ => ()
    }
  }
  Ok(events)
}
