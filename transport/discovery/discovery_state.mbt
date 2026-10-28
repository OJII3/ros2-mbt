///|
/// Return the receive result from one of the session's discovery sockets.
async fn DiscoverySession::receive_message(
  self : DiscoverySession,
) -> Result[(@rtps.Message, @socket.Addr), String] {
  if self.receive_sockets.length() == 0 {
    let (message, source) = match self.socket.receive_message() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    return Ok((message, source))
  }
  let tasks : Array[async () -> Result[(@rtps.Message, @socket.Addr), String]] = []
  tasks.push(async fn() {
    match self.socket.receive_message() {
      Ok((message, source)) => Ok((message, source))
      Err(message) => Err(message)
    }
  })
  for receive_socket in self.receive_sockets {
    tasks.push(async fn() {
      match receive_socket.receive_message() {
        Ok((message, source)) => Ok((message, source))
        Err(message) => Err(message)
      }
    })
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
      Ok((message, source)) => Ok(Message(message, source))
      Err(message) => Err(message)
    }
  })
  tasks.push(async fn() {
    self.deadline_changes.get()
    Ok(DeadlineChanged)
  })
  match self.engine.next_deadline() {
    Some(deadline) => {
      let delay = deadline - self.clock.now_ms()
      let delay = if delay < 0L { 0L } else { delay }
      tasks.push(async fn() {
        @async.sleep(discovery_lease_timer_segment(delay))
        Ok(ParticipantLeaseExpired)
      })
    }
    None => ()
  }
  @async.any(tasks, allow_failure=true)
}

///|
fn discovery_lease_timer_segment(remaining_ms : Int64) -> Int32 {
  if remaining_ms > DISCOVERY_MAX_TIMER_MILLISECONDS.to_int64() {
    DISCOVERY_MAX_TIMER_MILLISECONDS
  } else {
    remaining_ms.to_int()
  }
}

///|
fn discovery_addr_to_locator(address : @socket.Addr) -> @rtps.Locator {
  let ip = address.ip()
  @rtps.Locator::udp_v4(
    Bytes::from_array([
      (ip >> 24).to_byte(),
      (ip >> 16).to_byte(),
      (ip >> 8).to_byte(),
      ip.to_byte(),
    ]),
    address.port().reinterpret_as_uint(),
  ).unwrap()
}

///|
fn discovery_locator_to_addr(
  locator : @rtps.Locator,
) -> Result[@socket.Addr, String] {
  if locator.kind() != @rtps.LOCATOR_KIND_UDP_V4 {
    return Err("unsupported discovery locator transport")
  }
  if locator.port() == 0U || locator.port() > 65535U {
    return Err("invalid discovery UDP destination port")
  }
  let address = locator.address()
  let ip = (address[12].to_int().reinterpret_as_uint() << 24) |
    (address[13].to_int().reinterpret_as_uint() << 16) |
    (address[14].to_int().reinterpret_as_uint() << 8) |
    address[15].to_int().reinterpret_as_uint()
  Ok(@socket.Addr::new(ip, locator.port().reinterpret_as_int()))
}

///|
fn DiscoverySession::enqueue_outgoing(
  self : DiscoverySession,
  outgoing : Array[@participant_discovery.DiscoveryOutput],
) -> Unit {
  for output in outgoing {
    self.outgoing.push(output)
  }
}

///|
/// Commit accepted datagrams; retain send failures for retry. Destinations
/// this adapter can never deliver are kept separately for caller inspection.
async fn DiscoverySession::flush_outgoing_on(
  self : DiscoverySession,
  socket : @wire.Udp,
) -> Result[Unit, String] {
  self.send_lock.acquire()
  defer self.send_lock.release()
  // Attempt each queued effect once. A failed destination must not prevent
  // delivery to independent peers. New effects enqueued during a send are
  // handled by the next flush, without changing the current retry set.
  let mut remaining = self.outgoing.length()
  let mut index = 0
  let mut first_error : String? = None
  while remaining > 0 {
    remaining -= 1
    let output = self.outgoing[index]
    let destination = match discovery_locator_to_addr(output.destination) {
      Ok(value) => value
      Err(message) => {
        self.rejected_outgoing.push(output)
        self.outgoing.remove(index) |> ignore
        if first_error is None {
          first_error = Some(message)
        }
        continue
      }
    }
    let sent = socket.send_message(output.message, destination) catch {
      _ => Err("could not send discovery datagram")
    }
    match sent {
      Ok(_) => self.outgoing.remove(index) |> ignore
      Err(message) => {
        index += 1
        if first_error is None {
          first_error = Some(message)
        }
      }
    }
  }
  match first_error {
    Some(message) => Err(message)
    None => Ok(())
  }
}

///|
/// Retry queued discovery datagrams without allocating new sequence numbers.
pub async fn DiscoverySession::flush_outgoing(
  self : DiscoverySession,
) -> Result[Unit, String] {
  self.flush_outgoing_on(self.socket)
}

///|
fn DiscoverySession::enqueue_effects(
  self : DiscoverySession,
  effects : @participant_discovery.DiscoveryEffects,
  source : @socket.Addr,
) -> Unit {
  self.enqueue_outgoing(effects.outgoing)
  for event in effects.events {
    self.pending_events.push((discovery_wire_event(event), source))
  }
}

///|
fn discovery_wire_event(
  event : @participant_discovery.DiscoveryEvent,
) -> @wire.DiscoveryEvent {
  match event {
    Participant(value) => Participant(value)
    Publication(value) => Publication(value)
    Subscription(value) => Subscription(value)
    EndpointRemoved(kind, guid) => EndpointRemoved(kind, guid)
    ParticipantRemoved(guid) => ParticipantRemoved(guid)
  }
}

///|
fn DiscoverySession::queue_expired_participants(
  self : DiscoverySession,
) -> Unit {
  self.enqueue_effects(
    self.engine.advance(self.clock.now_ms()),
    @socket.Addr::new(0, 0),
  )
}

///|
/// Wake a receive already waiting without a heartbeat timer. Notifications are
/// coalesced and remain pending even if there is no active receive yet.
fn DiscoverySession::notify_deadline_change(self : DiscoverySession) -> Unit {
  ignore(self.deadline_changes.try_put(()) catch { _ => false })
}

///|
/// Take permanently rejected destinations, preserving their original messages
/// so the caller can inspect or reroute them. They never block the send queue.
pub fn DiscoverySession::take_rejected_outgoing(
  self : DiscoverySession,
) -> Array[@participant_discovery.DiscoveryOutput] {
  let rejected = self.rejected_outgoing
  self.rejected_outgoing = []
  rejected
}
