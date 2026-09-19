///|
/// A minimal reliable RTPS DataWriter with an in-memory history.
///
/// The caller drives HEARTBEAT transmission and passes decoded ACKNACKs to
/// `handle_acknack`. This keeps scheduling and socket receive ownership in the
/// application while providing the wire-level retransmission primitive.
/// Keep each fragment below common UDP payload limits, including RTPS headers.
const RELIABLE_WRITER_FRAGMENT_SIZE : Int = 1200

///|
struct ReliableFragmentedWrite {
  sequence_number : Int64
  fragments : Array[@rtps.DataFragSubmessage]
}

///|
fn reliable_writer_bytes_from(
  input : Bytes,
  start : Int,
  length : Int,
) -> Bytes {
  let bytes : Array[Byte] = []
  for i in 0..<length {
    bytes.push(input[start + i])
  }
  Bytes::from_array(bytes)
}

///|
fn reliable_writer_data_fits_datagram(data : @rtps.DataSubmessage) -> Bool {
  data.to_payload().length() + 4 + 20 <= RELIABLE_WRITER_FRAGMENT_SIZE
}

///|
fn reliable_writer_fragment_data(
  data : @rtps.DataSubmessage,
) -> Result[Array[@rtps.DataFragSubmessage], String] {
  let payload = data.serialized_payload()
  if payload.length() == 0 {
    return Err("cannot fragment an empty RTPS DATA payload")
  }
  let fragment_count =
    (payload.length() + RELIABLE_WRITER_FRAGMENT_SIZE - 1) /
      RELIABLE_WRITER_FRAGMENT_SIZE
  let fragments : Array[@rtps.DataFragSubmessage] = []
  for index in 0..<fragment_count {
    let offset = index * RELIABLE_WRITER_FRAGMENT_SIZE
    let length = if payload.length() - offset > RELIABLE_WRITER_FRAGMENT_SIZE {
      RELIABLE_WRITER_FRAGMENT_SIZE
    } else {
      payload.length() - offset
    }
    let fragment = match
      @rtps.DataFragSubmessage::new(
        data.reader_id(),
        data.writer_id(),
        data.writer_sequence_number(),
        (index + 1).reinterpret_as_uint(),
        (1 : Int).to_uint16(),
        RELIABLE_WRITER_FRAGMENT_SIZE.to_uint16(),
        payload.length().reinterpret_as_uint(),
        reliable_writer_bytes_from(payload, offset, length),
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    fragments.push(
      if index == 0 && data.inline_qos().length() > 0 {
        fragment.with_inline_qos(data.inline_qos())
      } else {
        fragment
      },
    )
  }
  Ok(fragments)
}

pub struct ReliableDataWriter {
  socket : Udp
  guid_prefix : @rtps.GuidPrefix
  vendor_id : @rtps.VendorId
  reader_id : @rtps.EntityId
  writer_id : @rtps.EntityId
  destinations : Array[@socket.Addr]
  reader_prefix : @rtps.GuidPrefix?
  mut next_sequence_number : Int64
  mut next_heartbeat_count : UInt
  history : Array[@rtps.DataSubmessage]
  fragmented_history : Array[ReliableFragmentedWrite]
}

///|
/// Create a reliable writer whose history is retained for retransmission.
pub fn ReliableDataWriter::new(
  socket : Udp,
  guid_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  reader_id : @rtps.EntityId,
  writer_id : @rtps.EntityId,
  destination : @socket.Addr,
  first_sequence_number : Int64,
) -> Result[ReliableDataWriter, String] {
  if first_sequence_number < 1L {
    return Err("an RTPS DATA sequence number must be positive")
  }
  Ok({
    socket,
    guid_prefix,
    vendor_id,
    reader_id,
    writer_id,
    destinations: [destination],
    reader_prefix: None,
    next_sequence_number: first_sequence_number,
    next_heartbeat_count: 1U,
    history: [],
    fragmented_history: [],
  })
}

///|
/// Create a reliable writer targeting a discovered SEDP subscription.
pub fn ReliableDataWriter::new_for_subscription(
  socket : Udp,
  guid_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  writer_id : @rtps.EntityId,
  subscription : @rtps.SedpEndpointData,
  first_sequence_number : Int64,
) -> Result[ReliableDataWriter, String] {
  if subscription.kind() != @rtps.SedpEndpointKind::Subscription {
    return Err("a reliable writer target must be an SEDP subscription")
  }
  let unicast_locators = subscription.unicast_locators()
  let locators = if unicast_locators.length() > 0 {
    unicast_locators
  } else {
    subscription.multicast_locators()
  }
  if locators.length() == 0 {
    return Err("the discovered subscription has no UDP locators")
  }
  let destinations = match udp_locator_to_addrs(locators) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let writer = match
    ReliableDataWriter::new(
      socket,
      guid_prefix,
      vendor_id,
      subscription.endpoint_guid().entity_id(),
      writer_id,
      destinations[0],
      first_sequence_number,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({
    ..writer,
    destinations,
    reader_prefix: Some(subscription.endpoint_guid().prefix()),
  })
}

///|
/// Create a reliable writer for one SEDP endpoint announcement.
///
/// The returned writer uses the local endpoint participant prefix and the
/// builtin SEDP reader/writer IDs selected by the endpoint kind.
pub fn ReliableDataWriter::new_for_sedp(
  socket : Udp,
  vendor_id : @rtps.VendorId,
  endpoint : @rtps.SedpEndpointData,
  remote_participant : @rtps.SpdpParticipantData,
  first_sequence_number : Int64,
) -> Result[ReliableDataWriter, String] {
  let unicast_locators = remote_participant.metatraffic_unicast_locators()
  let locators = if unicast_locators.length() > 0 {
    unicast_locators
  } else {
    remote_participant.metatraffic_multicast_locators()
  }
  if locators.length() == 0 {
    return Err("the remote participant has no metatraffic locators")
  }
  let destinations = match udp_locator_to_addrs(locators) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let kind = endpoint.kind()
  let writer = match
    ReliableDataWriter::new(
      socket,
      endpoint.participant_guid().prefix(),
      vendor_id,
      kind.builtin_reader_id(),
      kind.builtin_writer_id(),
      destinations[0],
      first_sequence_number,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({
    ..writer,
    destinations,
    reader_prefix: Some(remote_participant.participant_guid().prefix()),
  })
}

///|
pub fn ReliableDataWriter::next_sequence_number(
  self : ReliableDataWriter,
) -> Int64 {
  self.next_sequence_number
}

///|
/// Return the vendor ID used in outgoing RTPS message headers.
pub fn ReliableDataWriter::vendor_id(
  self : ReliableDataWriter,
) -> @rtps.VendorId {
  self.vendor_id
}

///|
pub fn ReliableDataWriter::next_heartbeat_count(
  self : ReliableDataWriter,
) -> UInt {
  self.next_heartbeat_count
}

///|
/// Return the number of samples retained for retransmission.
pub fn ReliableDataWriter::history_length(self : ReliableDataWriter) -> Int {
  self.history.length()
}

///|
/// Send one sample and retain it in the reliable writer history.
pub async fn ReliableDataWriter::write(
  self : ReliableDataWriter,
  serialized_payload : Bytes,
) -> Result[Unit, String] {
  let sequence_number = self.next_sequence_number
  let data = @rtps.DataSubmessage::new(
    self.reader_id,
    self.writer_id,
    sequence_number,
    serialized_payload,
  )
  match self.write_data(data) {
    Ok(_) => Ok(())
    Err(message) => Err(message)
  }
}

///|
/// Send one sample and return its RTPS sample identity.
pub async fn ReliableDataWriter::write_and_return_identity(
  self : ReliableDataWriter,
  serialized_payload : Bytes,
) -> Result[@rtps.SampleIdentity, String] {
  let sequence_number = self.next_sequence_number
  let data = @rtps.DataSubmessage::new(
    self.reader_id,
    self.writer_id,
    sequence_number,
    serialized_payload,
  )
  self.write_data(data)
}

///|
/// Send a reply sample with the DDS-RPC related request identity.
pub async fn ReliableDataWriter::write_with_related_sample_identity(
  self : ReliableDataWriter,
  serialized_payload : Bytes,
  related_identity : @rtps.SampleIdentity,
) -> Result[Unit, String] {
  match
    self.write_with_related_sample_identity_and_return_identity(
      serialized_payload, related_identity,
    ) {
    Ok(_) => Ok(())
    Err(message) => Err(message)
  }
}

///|
/// Send a related sample and return the reply's own RTPS sample identity.
pub async fn ReliableDataWriter::write_with_related_sample_identity_and_return_identity(
  self : ReliableDataWriter,
  serialized_payload : Bytes,
  related_identity : @rtps.SampleIdentity,
) -> Result[@rtps.SampleIdentity, String] {
  let sequence_number = self.next_sequence_number
  let data = @rtps.DataSubmessage::new(
    self.reader_id,
    self.writer_id,
    sequence_number,
    serialized_payload,
  ).with_related_sample_identity(related_identity)
  self.write_data(data)
}

///|
/// Send a DATA sample and retain it for ACKNACK retransmission.
async fn ReliableDataWriter::write_data(
  self : ReliableDataWriter,
  data : @rtps.DataSubmessage,
) -> Result[@rtps.SampleIdentity, String] {
  if !reliable_writer_data_fits_datagram(data) {
    let fragments = match reliable_writer_fragment_data(data) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    for index in 0..<fragments.length() {
      let fragment = fragments[index]
      for destination in self.destinations {
        match
          self.socket.send_message(
            fragment.to_message(self.guid_prefix, self.vendor_id),
            destination,
          ) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      }
    }
    self.history.push(data)
    self.fragmented_history.push({
      sequence_number: data.writer_sequence_number(),
      fragments,
    })
    self.next_sequence_number = data.writer_sequence_number() + 1L
    return data.sample_identity(self.guid_prefix)
  }
  for destination in self.destinations {
    match
      self.socket.send_data(
        data,
        self.guid_prefix,
        self.vendor_id,
        destination,
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  self.history.push(data)
  self.next_sequence_number = data.writer_sequence_number() + 1L
  match data.sample_identity(self.guid_prefix) {
    Ok(identity) => Ok(identity)
    Err(message) => Err(message)
  }
}

///|
/// Announce the currently retained sequence range to the remote reader.
pub async fn ReliableDataWriter::send_heartbeat(
  self : ReliableDataWriter,
) -> Result[Unit, String] {
  if self.history.length() == 0 {
    return Err("cannot send a HEARTBEAT before the first sample")
  }
  let first_sequence_number = self.history[0].writer_sequence_number()
  let last_sequence_number = self.history[self.history.length() - 1].writer_sequence_number()
  let heartbeat = match
    @rtps.HeartbeatSubmessage::new(
      self.reader_id,
      self.writer_id,
      first_sequence_number,
      last_sequence_number,
      self.next_heartbeat_count,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  for destination in self.destinations {
    match
      self.socket.send_heartbeat(
        heartbeat,
        self.guid_prefix,
        self.vendor_id,
        destination,
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  for fragmented in self.fragmented_history {
    let heartbeat_frag = match
      @rtps.HeartbeatFragSubmessage::new(
        self.reader_id,
        self.writer_id,
        fragmented.sequence_number,
        fragmented.fragments.length().reinterpret_as_uint(),
        self.next_heartbeat_count,
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    for destination in self.destinations {
      match
        self.socket.send_heartbeat_frag(
          heartbeat_frag,
          self.guid_prefix,
          self.vendor_id,
          destination,
        ) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    }
  }
  self.next_heartbeat_count += 1U
  Ok(())
}

///|
fn reliable_bitmap_contains(bitmap : Array[UInt], offset : Int) -> Bool {
  let word_index = offset / 32
  let bit_index = offset % 32
  let mask : UInt = 0x80000000U >> bit_index
  (bitmap[word_index] & mask) != 0U
}

///|
/// Retransmit the sequence numbers selected by an ACKNACK bitmap.
pub async fn ReliableDataWriter::handle_acknack(
  self : ReliableDataWriter,
  acknack : @rtps.AckNackSubmessage,
) -> Result[Unit, String] {
  if acknack.writer_id() != self.writer_id {
    return Err("the ACKNACK targets a different RTPS writer")
  }
  if acknack.reader_id() != self.reader_id {
    return Err("the ACKNACK targets a different RTPS reader")
  }
  let bitmap = acknack.bitmap()
  let num_bits = acknack.num_bits().reinterpret_as_int()
  for offset in 0..<num_bits {
    if !reliable_bitmap_contains(bitmap, offset) {
      continue
    }
    let requested_sequence = acknack.bitmap_base() + offset.to_int64()
    let mut fragmented_found = false
    for fragmented in self.fragmented_history {
      if fragmented.sequence_number != requested_sequence {
        continue
      }
      fragmented_found = true
      for fragment in fragmented.fragments {
        for destination in self.destinations {
          match
            self.socket.send_message(
              fragment.to_message(self.guid_prefix, self.vendor_id),
              destination,
            ) {
            Ok(_) => ()
            Err(message) => return Err(message)
          }
        }
      }
    }
    if fragmented_found {
      continue
    }
    for sample in self.history {
      if sample.writer_sequence_number() != requested_sequence {
        continue
      }
      for destination in self.destinations {
        match
          self.socket.send_data(
            sample,
            self.guid_prefix,
            self.vendor_id,
            destination,
          ) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      }
    }
  }
  Ok(())
}

///|
/// Retransmit fragments selected by a NACK_FRAG bitmap.
pub async fn ReliableDataWriter::handle_nackfrag(
  self : ReliableDataWriter,
  nackfrag : @rtps.NackFragSubmessage,
) -> Result[Unit, String] {
  if nackfrag.writer_id() != self.writer_id {
    return Err("the NACK_FRAG targets a different RTPS writer")
  }
  if nackfrag.reader_id() != self.reader_id {
    return Err("the NACK_FRAG targets a different RTPS reader")
  }
  let bitmap = nackfrag.bitmap()
  let num_bits = nackfrag.num_bits().reinterpret_as_int()
  for fragmented in self.fragmented_history {
    if fragmented.sequence_number != nackfrag.writer_sequence_number() {
      continue
    }
    for offset in 0..<num_bits {
      if !reliable_bitmap_contains(bitmap, offset) {
        continue
      }
      let fragment_number = nackfrag.bitmap_base().reinterpret_as_int() + offset
      if fragment_number < 1 || fragment_number > fragmented.fragments.length() {
        continue
      }
      let fragment = fragmented.fragments[fragment_number - 1]
      for destination in self.destinations {
        match
          self.socket.send_message(
            fragment.to_message(self.guid_prefix, self.vendor_id),
            destination,
          ) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      }
    }
  }
  Ok(())
}

///|
/// Receive one ACKNACK from the socket and retransmit its requested samples.
pub async fn ReliableDataWriter::receive_acknack(
  self : ReliableDataWriter,
) -> Result[(@rtps.AckNackSubmessage, @socket.Addr), String] {
  while true {
    let (message, source) = match self.socket.receive_message() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    for submessage in message.submessages() {
      if submessage.id() != @rtps.SubmessageId::AckNack {
        continue
      }
      let acknack = match @rtps.AckNackSubmessage::from_submessage(submessage) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let prefix_matches = match self.reader_prefix {
        Some(prefix) => message.header().guid_prefix() == prefix
        None => true
      }
      if acknack.writer_id() != self.writer_id ||
        acknack.reader_id() != self.reader_id ||
        !prefix_matches {
        continue
      }
      match self.handle_acknack(acknack) {
        Ok(_) => return Ok((acknack, source))
        Err(message) => return Err(message)
      }
    }
  }
  Err("reliable writer stopped")
}

///|
/// Receive one NACK_FRAG and retransmit its requested fragments.
pub async fn ReliableDataWriter::receive_nackfrag(
  self : ReliableDataWriter,
) -> Result[(@rtps.NackFragSubmessage, @socket.Addr), String] {
  while true {
    let (message, source) = match self.socket.receive_message() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    for submessage in message.submessages() {
      if submessage.id() != @rtps.SubmessageId::NackFrag {
        continue
      }
      let nackfrag = match @rtps.NackFragSubmessage::from_submessage(submessage) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let prefix_matches = match self.reader_prefix {
        Some(prefix) => message.header().guid_prefix() == prefix
        None => true
      }
      if nackfrag.writer_id() != self.writer_id ||
        nackfrag.reader_id() != self.reader_id ||
        !prefix_matches {
        continue
      }
      match self.handle_nackfrag(nackfrag) {
        Ok(_) => return Ok((nackfrag, source))
        Err(message) => return Err(message)
      }
    }
  }
  Err("reliable writer stopped")
}

///|
/// Receive either reliable-reader control message and retransmit its requests.
///
/// This is useful for an application task that shares one socket with the
/// writer: a fragmented sample may require both ACKNACK and NACK_FRAG handling.
pub async fn ReliableDataWriter::receive_control(
  self : ReliableDataWriter,
) -> Result[Unit, String] {
  while true {
    let (message, _) = match self.socket.receive_message() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    for submessage in message.submessages() {
      match submessage.id() {
        @rtps.SubmessageId::AckNack => {
          let acknack = match @rtps.AckNackSubmessage::from_submessage(submessage) {
            Ok(value) => value
            Err(message) => return Err(message)
          }
          let prefix_matches = match self.reader_prefix {
            Some(prefix) => message.header().guid_prefix() == prefix
            None => true
          }
          if acknack.writer_id() != self.writer_id ||
            acknack.reader_id() != self.reader_id ||
            !prefix_matches {
            continue
          }
          match self.handle_acknack(acknack) {
            Ok(_) => return Ok(())
            Err(message) => return Err(message)
          }
        }
        @rtps.SubmessageId::NackFrag => {
          let nackfrag = match @rtps.NackFragSubmessage::from_submessage(submessage) {
            Ok(value) => value
            Err(message) => return Err(message)
          }
          let prefix_matches = match self.reader_prefix {
            Some(prefix) => message.header().guid_prefix() == prefix
            None => true
          }
          if nackfrag.writer_id() != self.writer_id ||
            nackfrag.reader_id() != self.reader_id ||
            !prefix_matches {
            continue
          }
          match self.handle_nackfrag(nackfrag) {
            Ok(_) => return Ok(())
            Err(message) => return Err(message)
          }
        }
        _ => continue
      }
    }
  }
  Err("reliable writer stopped")
}

///|
/// Close the reliable writer's underlying UDP socket.
pub fn ReliableDataWriter::close(self : ReliableDataWriter) -> Unit {
  self.socket.close()
}
