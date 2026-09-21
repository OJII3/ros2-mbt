///|
/// Return the receive result from one of the session's discovery sockets.
async fn DiscoverySession::receive_message(
  self : DiscoverySession,
) -> Result[(@rtps.Message, @socket.Addr, Int), String] {
  if self.receive_sockets.length() == 0 {
    let (message, source) = match self.socket.receive_message() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    return Ok((message, source, 0))
  }
  let tasks : Array[
    async () -> Result[(@rtps.Message, @socket.Addr, Int), String],
  ] = []
  tasks.push(async fn() {
    match self.socket.receive_message() {
      Ok((message, source)) => Ok((message, source, 0))
      Err(message) => Err(message)
    }
  })
  let mut receive_index = 1
  for receive_socket in self.receive_sockets {
    let index = receive_index
    tasks.push(async fn() {
      match receive_socket.receive_message() {
        Ok((message, source)) => Ok((message, source, index))
        Err(message) => Err(message)
      }
    })
    receive_index += 1
  }
  @async.any(tasks, allow_failure=true)
}

///|
async fn DiscoverySession::receive_message_or_lease_expiry(
  self : DiscoverySession,
) -> Result[DiscoveryReceiveOutcome, String] {
  let tasks : Array[async () -> Result[DiscoveryReceiveOutcome, String]] = []
  tasks.push(async fn() {
    match self.receive_message() {
      Ok((message, source, socket_index)) =>
        Ok(DiscoveryReceiveOutcome::Message(message, source, socket_index))
      Err(message) => Err(message)
    }
  })
  for remote in self.remote_participants {
    match remote.lease_timer {
      Some(timer) => {
        let participant_guid = remote.participant.participant_guid()
        tasks.push(async fn() {
          timer.wait()
          Ok(DiscoveryReceiveOutcome::ParticipantLeaseExpired(participant_guid))
        })
      }
      None => ()
    }
  }
  @async.any(tasks, allow_failure=true)
}

///|
/// Locate or create reliable receive state for one remote SEDP writer.
fn DiscoverySession::sedp_reader_index(
  self : DiscoverySession,
  writer_prefix : @rtps.GuidPrefix,
  writer_id : @rtps.EntityId,
) -> Result[Int, String] {
  for index in 0..<self.sedp_readers.length() {
    let reader = self.sedp_readers[index]
    if reader.writer_prefix == writer_prefix && reader.writer_id == writer_id {
      return Ok(index)
    }
  }
  let kind = match @rtps.SedpEndpointKind::from_builtin_writer_id(writer_id) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  self.sedp_readers.push({
    writer_prefix,
    writer_id,
    reader: ReliableDataReader::new(kind.builtin_reader_id(), writer_id),
  })
  Ok(self.sedp_readers.length() - 1)
}

///|
/// Locate or create fragment assembly state for one remote SPDP writer.
fn DiscoverySession::spdp_fragment_reader_index(
  self : DiscoverySession,
  writer_prefix : @rtps.GuidPrefix,
) -> Int {
  for index in 0..<self.spdp_fragment_readers.length() {
    if self.spdp_fragment_readers[index].writer_prefix == writer_prefix {
      return index
    }
  }
  self.spdp_fragment_readers.push({
    writer_prefix,
    writer_id: self.writer_id,
    reader: ReliableDataReader::new(self.reader_id, self.writer_id),
  })
  self.spdp_fragment_readers.length() - 1
}

///|
/// Retain the latest SPDP locators for one remote participant.
fn DiscoverySession::remember_remote_participant(
  self : DiscoverySession,
  participant : @rtps.SpdpParticipantData,
) -> Unit {
  if participant.participant_guid() == self.participant.participant_guid() {
    return
  }
  let lease_remaining_ms = discovery_spdp_lease_milliseconds(participant)
  for index in 0..<self.remote_participants.length() {
    if self.remote_participants[index].participant.participant_guid() ==
      participant.participant_guid() {
      self.remote_participants[index].participant = participant
      match (self.remote_participants[index].lease_timer, lease_remaining_ms) {
        (Some(timer), Some(remaining_ms)) => {
          let segment_ms = discovery_lease_timer_segment(remaining_ms)
          self.remote_participants[index].lease_remaining_ms = remaining_ms
          if segment_ms == self.remote_participants[index].lease_segment_ms {
            timer.refresh()
          } else {
            timer.cancel()
            self.remote_participants[index].lease_timer = Some(
              @async.Timer::Timer(segment_ms),
            )
            self.remote_participants[index].lease_segment_ms = segment_ms
          }
        }
        (Some(timer), None) => {
          timer.cancel()
          self.remote_participants[index].lease_timer = None
          self.remote_participants[index].lease_remaining_ms = 0L
          self.remote_participants[index].lease_segment_ms = 0
        }
        (None, Some(remaining_ms)) => {
          let segment_ms = discovery_lease_timer_segment(remaining_ms)
          self.remote_participants[index].lease_timer = Some(
            @async.Timer::Timer(segment_ms),
          )
          self.remote_participants[index].lease_remaining_ms = remaining_ms
          self.remote_participants[index].lease_segment_ms = segment_ms
        }
        (None, None) => ()
      }
      return
    }
  }
  let mut timer = None
  let mut remaining_ms = 0L
  let mut segment_ms = 0
  match lease_remaining_ms {
    Some(value) => {
      remaining_ms = value
      segment_ms = discovery_lease_timer_segment(value)
      timer = Some(@async.Timer::Timer(segment_ms))
    }
    None => ()
  }
  self.remote_participants.push({
    participant,
    lease_timer: timer,
    lease_remaining_ms: remaining_ms,
    lease_segment_ms: segment_ms,
  })
}

///|
fn discovery_spdp_lease_milliseconds(
  participant : @rtps.SpdpParticipantData,
) -> Int64? {
  let seconds = participant.lease_seconds()
  let nanoseconds = participant.lease_nanoseconds()
  if seconds == 0x7FFFFFFF && nanoseconds == 0xFFFFFFFFU {
    return None
  }
  if seconds < 0 || nanoseconds >= 1_000_000_000U {
    return None
  }
  let fractional_milliseconds = (nanoseconds.to_uint64() + 999_999U.to_uint64()) /
    1_000_000U.to_uint64()
  Some(
    seconds.to_int64() * 1000L + fractional_milliseconds.reinterpret_as_int64(),
  )
}

///|
fn discovery_lease_timer_segment(remaining_ms : Int64) -> Int {
  if remaining_ms > DISCOVERY_MAX_TIMER_MILLISECONDS.to_int64() {
    DISCOVERY_MAX_TIMER_MILLISECONDS
  } else {
    remaining_ms.to_int()
  }
}

///|
fn DiscoverySession::advance_expired_participant_lease(
  self : DiscoverySession,
  participant_guid : @rtps.Guid,
) -> Bool {
  for remote in self.remote_participants {
    if remote.participant.participant_guid() != participant_guid {
      continue
    }
    if remote.lease_timer is None {
      return false
    }
    if remote.lease_remaining_ms > remote.lease_segment_ms.to_int64() {
      remote.lease_remaining_ms -= remote.lease_segment_ms.to_int64()
      remote.lease_segment_ms = discovery_lease_timer_segment(
        remote.lease_remaining_ms,
      )
      remote.lease_timer = Some(@async.Timer::Timer(remote.lease_segment_ms))
      return false
    }
    return true
  }
  false
}

///|
/// Forget one remote participant and its advertised locators.
fn DiscoverySession::forget_remote_participant(
  self : DiscoverySession,
  participant_guid : @rtps.Guid,
) -> Unit {
  let remaining : Array[DiscoveryRemoteParticipant] = []
  for remote in self.remote_participants {
    if remote.participant.participant_guid() != participant_guid {
      remaining.push(remote)
    } else {
      match remote.lease_timer {
        Some(timer) => timer.cancel()
        None => ()
      }
    }
  }
  self.remote_participants = remaining
  let sedp_readers : Array[DiscoveryRemoteDataReader] = []
  for reader in self.sedp_readers {
    if reader.writer_prefix != participant_guid.prefix() {
      sedp_readers.push(reader)
    }
  }
  self.sedp_readers = sedp_readers
  let spdp_fragment_readers : Array[DiscoveryRemoteDataReader] = []
  for reader in self.spdp_fragment_readers {
    if reader.writer_prefix != participant_guid.prefix() {
      spdp_fragment_readers.push(reader)
    }
  }
  self.spdp_fragment_readers = spdp_fragment_readers
}

///|
/// Resolve an ACKNACK destination from SPDP, falling back to the packet source.
fn DiscoverySession::acknowledgement_destination(
  self : DiscoverySession,
  participant_prefix : @rtps.GuidPrefix,
  source : @socket.Addr,
) -> @socket.Addr {
  for remote in self.remote_participants {
    let participant = remote.participant
    if participant.participant_guid().prefix() != participant_prefix {
      continue
    }
    match udp_locator_to_addrs(participant.metatraffic_unicast_locators()) {
      Ok(addresses) if addresses.length() > 0 => return addresses[0]
      _ => ()
    }
  }
  source
}

///|
/// Locate or create history for one local SEDP writer kind.
fn DiscoverySession::sedp_writer_index(
  self : DiscoverySession,
  kind : @rtps.SedpEndpointKind,
) -> Int {
  for index in 0..<self.sedp_writers.length() {
    if self.sedp_writers[index].kind == kind {
      return index
    }
  }
  self.sedp_writers.push({ kind, samples: [], })
  self.sedp_writers.length() - 1
}

///|
/// Retain one local SEDP sample for ACKNACK-driven retransmission.
fn DiscoverySession::remember_sedp_sample(
  self : DiscoverySession,
  endpoint : @rtps.SedpEndpointData,
  vendor_id : @rtps.VendorId,
  sequence_number : Int64,
) -> Result[Unit, String] {
  let kind = endpoint.kind()
  let sample = match
    endpoint.to_data_submessage_with_vendor(
      vendor_id,
      kind.builtin_reader_id(),
      kind.builtin_writer_id(),
      sequence_number,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  self.remember_sedp_data(kind, sequence_number, sample)
}

///|
/// Retain one SEDP DATA sample for ACKNACK-driven retransmission.
fn DiscoverySession::remember_sedp_data(
  self : DiscoverySession,
  kind : @rtps.SedpEndpointKind,
  sequence_number : Int64,
  sample : @rtps.DataSubmessage,
) -> Result[Unit, String] {
  let index = self.sedp_writer_index(kind)
  for sample_index in 0..<self.sedp_writers[index].samples.length() {
    if self.sedp_writers[index].samples[sample_index].writer_sequence_number() ==
      sequence_number {
      self.sedp_writers[index].samples[sample_index] = sample
      return Ok(())
    }
  }
  self.sedp_writers[index].samples.push(sample)
  Ok(())
}

///|
/// Retain one SEDP endpoint dispose sample for ACKNACK-driven retransmission.
fn DiscoverySession::remember_sedp_dispose_sample(
  self : DiscoverySession,
  endpoint : @rtps.SedpEndpointData,
  sequence_number : Int64,
) -> Result[Unit, String] {
  let kind = endpoint.kind()
  let sample = endpoint.to_dispose_data_submessage(
    kind.builtin_reader_id(),
    kind.builtin_writer_id(),
    sequence_number,
  )
  self.remember_sedp_data(kind, sequence_number, sample)
}

///|
/// Remember a received SEDP DATA sample for later ACKNACK generation.
fn DiscoverySession::record_sedp_data(
  self : DiscoverySession,
  writer_prefix : @rtps.GuidPrefix,
  data : @rtps.DataSubmessage,
) -> Unit {
  let index = match self.sedp_reader_index(writer_prefix, data.writer_id()) {
    Ok(value) => value
    Err(_) => return
  }
  ignore(self.sedp_readers[index].reader.accept_data(data))
}

