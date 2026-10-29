///|
/// Datagram payload budget, leaving room for RTPS and destination headers.
const DISCOVERY_FRAGMENT_SIZE : Int32 = 1200

///|
/// Keep the latest announcement or tombstone for each endpoint, with fixed
/// writer-local admission limits. Replacing an endpoint does not grow history.
const DISCOVERY_HISTORY_MAX_ENDPOINTS : Int32 = 1024

///|
const DISCOVERY_HISTORY_MAX_BYTES : Int32 = 16 * 1024 * 1024

///|
const DISCOVERY_MAX_READER_CONTROLS : Int32 = 256

///|
priv struct DiscoveryWrite {
  endpoint_guid : @core.Guid
  data : @core.DataSubmessage
  fragments : Array[@core.DataFragSubmessage]
}

///|
struct DiscoveryWriter {
  kind : SedpEndpointKind
  mut next_sequence : Int64
  mut sequence_exhausted : Bool
  mut next_heartbeat : UInt32
  mut history : Array[DiscoveryWrite]
}

///|
struct DiscoveryReaderControl {
  prefix : @core.GuidPrefix
  kind : SedpEndpointKind
  mut acknack_count : UInt32?
  mut nackfrag_count : UInt32?
}

///|
/// I/O-free discovery transmission. Producing effects consumes sequence/count
/// values, independently of whether the caller succeeds in sending them.
/// SEDP history is transient-local: acknowledgements from one remote reader
/// never discard samples needed by other readers or late joiners.
pub struct DiscoverySender {
  participant : SpdpParticipantData
  reader_id : @core.EntityId
  writer_id : @core.EntityId
  destination : @core.Locator
  mut next_sequence : Int64
  mut sequence_exhausted : Bool
  priv mut spdp_data : @core.DataSubmessage?
  priv mut spdp_fragments : Array[@core.DataFragSubmessage]
  priv mut spdp_dispose_state : Bool?
  writers : Array[DiscoveryWriter]
  mut controls : Array[DiscoveryReaderControl]
}

///|
pub fn DiscoverySender::new(
  participant : SpdpParticipantData,
  reader_id : @core.EntityId,
  writer_id : @core.EntityId,
  destination : @core.Locator,
  first_sequence_number : Int64,
) -> Result[DiscoverySender, String] {
  if first_sequence_number < 1L {
    return Err("an SPDP sequence number must be positive")
  }
  Ok({
    participant,
    reader_id,
    writer_id,
    destination,
    next_sequence: first_sequence_number,
    sequence_exhausted: false,
    spdp_data: None,
    spdp_fragments: [],
    spdp_dispose_state: None,
    writers: [],
    controls: [],
  })
}

///|
pub fn DiscoverySender::next_sequence_number(self : DiscoverySender) -> Int64 {
  self.next_sequence
}

///|
fn discovery_fragment_data(
  data : @core.DataSubmessage,
) -> Result[Array[@core.DataFragSubmessage], String] {
  if data.to_payload().length() + 40 <= DISCOVERY_FRAGMENT_SIZE {
    return Ok([])
  }
  let payload = data.serialized_payload()
  if payload.length() == 0 {
    return Err("cannot fragment an empty discovery DATA payload")
  }
  let fragments : Array[@core.DataFragSubmessage] = []
  let count = (payload.length() + DISCOVERY_FRAGMENT_SIZE - 1) /
    DISCOVERY_FRAGMENT_SIZE
  for index in 0..<count {
    let offset = index * DISCOVERY_FRAGMENT_SIZE
    let length = if payload.length() - offset > DISCOVERY_FRAGMENT_SIZE {
      DISCOVERY_FRAGMENT_SIZE
    } else {
      payload.length() - offset
    }
    let bytes : Array[Byte] = []
    for i in 0..<length {
      bytes.push(payload[offset + i])
    }
    let fragment = match
      @core.DataFragSubmessage::new(
        data.reader_id(),
        data.writer_id(),
        data.writer_sequence_number(),
        (index + 1).reinterpret_as_uint(),
        (1 : Int32).to_uint16(),
        DISCOVERY_FRAGMENT_SIZE.to_uint16(),
        payload.length().reinterpret_as_uint(),
        Bytes::from_array(bytes),
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let fragment = if (data.flags() & @core.DATA_FLAG_KEY) != 0 {
      match
        @core.DataFragSubmessage::from_submessage(
          @core.Submessage::new(
            DataFrag,
            fragment.flags() | @core.DATA_FRAG_FLAG_KEY,
            fragment.to_payload(),
          ),
        ) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
    } else {
      fragment
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

///|
fn DiscoverySender::data_messages(
  self : DiscoverySender,
  write : DiscoveryWrite,
) -> Array[@core.Message] {
  let prefix = self.participant.participant_guid().prefix()
  let vendor = self.participant.vendor_id()
  if write.fragments.length() == 0 {
    [write.data.to_message(prefix, vendor)]
  } else {
    write.fragments.map(fn(fragment) { fragment.to_message(prefix, vendor) })
  }
}

///|
fn DiscoverySender::spdp_outputs(
  self : DiscoverySender,
  write : DiscoveryWrite,
) -> Array[DiscoveryOutput] {
  self
  .data_messages(write)
  .map(fn(message) {
    DiscoveryOutput::{ message, destination: self.destination, }
  })
}

///|
pub fn DiscoverySender::announce_spdp(
  self : DiscoverySender,
  dispose : Bool,
) -> Result[Array[DiscoveryOutput], String] {
  match (self.spdp_data, self.spdp_dispose_state) {
    (Some(data), Some(previous_dispose)) if previous_dispose == dispose =>
      return Ok(
        self.spdp_outputs({
          endpoint_guid: self.participant.participant_guid(),
          data,
          fragments: self.spdp_fragments,
        }),
      )
    _ => ()
  }
  if self.sequence_exhausted {
    return Err("the SPDP sequence number space is exhausted")
  }
  let data = if dispose {
    self.participant.to_dispose_data_submessage(
      self.reader_id,
      self.writer_id,
      self.next_sequence,
    )
  } else {
    self.participant.to_data_submessage(
      self.reader_id,
      self.writer_id,
      self.next_sequence,
    )
  }
  let fragments = match discovery_fragment_data(data) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let write = DiscoveryWrite::{
    endpoint_guid: self.participant.participant_guid(),
    data,
    fragments,
  }
  if self.next_sequence == 0x7FFFFFFFFFFFFFFFL {
    self.sequence_exhausted = true
  } else {
    self.next_sequence += 1L
  }
  self.spdp_data = Some(data)
  self.spdp_fragments = fragments
  self.spdp_dispose_state = Some(dispose)
  Ok(self.spdp_outputs(write))
}

///|
fn DiscoverySender::writer(
  self : DiscoverySender,
  kind : SedpEndpointKind,
) -> DiscoveryWriter {
  for writer in self.writers {
    if writer.kind == kind {
      return writer
    }
  }
  let writer = DiscoveryWriter::{
    kind,
    next_sequence: 1L,
    sequence_exhausted: false,
    next_heartbeat: 1U,
    history: [],
  }
  self.writers.push(writer)
  writer
}

///|
pub fn DiscoverySender::next_sedp_sequence_number(
  self : DiscoverySender,
  kind : SedpEndpointKind,
) -> Int64 {
  self.writer(kind).next_sequence
}

///|
fn DiscoverySender::metatraffic_locators(
  self : DiscoverySender,
  participant : SpdpParticipantData,
) -> Array[@core.Locator] {
  let unicast = participant
    .metatraffic_unicast_locators()
    .filter(fn(locator) { locator.kind() == self.destination.kind() })
  if unicast.length() > 0 {
    unicast
  } else {
    participant
    .metatraffic_multicast_locators()
    .filter(fn(locator) { locator.kind() == self.destination.kind() })
  }
}

///|
pub fn DiscoverySender::announce_sedp(
  self : DiscoverySender,
  endpoint : SedpEndpointData,
  remotes : Array[SpdpParticipantData],
  dispose : Bool,
) -> Result[Array[DiscoveryOutput], String] {
  let kind = endpoint.kind()
  let writer = self.writer(kind)
  if writer.sequence_exhausted {
    return Err("the SEDP sequence number space is exhausted")
  }
  let data = if dispose {
    endpoint.to_dispose_data_submessage(
      kind.builtin_reader_id(),
      kind.builtin_writer_id(),
      writer.next_sequence,
    )
  } else {
    match
      endpoint.to_data_submessage_with_vendor(
        self.participant.vendor_id(),
        kind.builtin_reader_id(),
        kind.builtin_writer_id(),
        writer.next_sequence,
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
  }
  let fragments = match discovery_fragment_data(data) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let write = DiscoveryWrite::{
    endpoint_guid: endpoint.endpoint_guid(),
    data,
    fragments,
  }
  let retained = writer.history.filter(fn(previous) {
    previous.endpoint_guid != endpoint.endpoint_guid()
  })
  let mut history_bytes = discovery_write_bytes(write)
  for previous in retained {
    history_bytes += discovery_write_bytes(previous)
  }
  if retained.length() >= DISCOVERY_HISTORY_MAX_ENDPOINTS ||
    history_bytes > DISCOVERY_HISTORY_MAX_BYTES {
    return Err("the SEDP retained history limit is exceeded")
  }
  let messages = self.data_messages(write)
  let outputs : Array[DiscoveryOutput] = []
  for remote in remotes {
    if remote.participant_guid() == self.participant.participant_guid() {
      continue
    }
    let locators = self.metatraffic_locators(remote)
    for destination in locators {
      for message in messages {
        outputs.push({
          message: message.with_destination_guid_prefix(
            remote.participant_guid().prefix(),
          ),
          destination,
        })
      }
    }
  }
  writer.history = retained
  writer.history.push(write)
  if writer.next_sequence == 0x7FFFFFFFFFFFFFFFL {
    writer.sequence_exhausted = true
  } else {
    writer.next_sequence += 1L
  }
  for heartbeat in self.heartbeats_for_writer(writer, remotes) {
    outputs.push(heartbeat)
  }
  Ok(outputs)
}

///|
fn DiscoverySender::control(
  self : DiscoverySender,
  prefix : @core.GuidPrefix,
  kind : SedpEndpointKind,
) -> DiscoveryReaderControl? {
  for control in self.controls {
    if control.prefix == prefix && control.kind == kind {
      return Some(control)
    }
  }
  if self.controls.length() >= DISCOVERY_MAX_READER_CONTROLS {
    return None
  }
  let control = DiscoveryReaderControl::{
    prefix,
    kind,
    acknack_count: None,
    nackfrag_count: None,
  }
  self.controls.push(control)
  Some(control)
}

///|
fn discovery_control_count_is_new(previous : UInt32?, count : UInt32) -> Bool {
  match previous {
    None => true
    Some(previous) => (count - previous).reinterpret_as_int() > 0
  }
}

///|
fn discovery_sender_bitmap_contains(
  bitmap : Array[UInt32],
  offset : Int32,
) -> Bool {
  (bitmap[offset / 32] & (0x80000000U >> (offset % 32))) != 0U
}

///|
pub fn DiscoverySender::retransmit_acknack(
  self : DiscoverySender,
  reader_prefix : @core.GuidPrefix,
  acknack : @core.AckNackSubmessage,
  source : @core.Locator,
) -> Result[Array[DiscoveryOutput], String] {
  let kind = match
    SedpEndpointKind::from_builtin_writer_id(acknack.writer_id()) {
    Ok(value) => value
    Err(_) => return Ok([])
  }
  if acknack.reader_id() != kind.builtin_reader_id() &&
    acknack.reader_id() != @core.EntityId::unknown() {
    return Ok([])
  }
  let mut known_writer : DiscoveryWriter? = None
  for writer in self.writers {
    if writer.kind == kind {
      known_writer = Some(writer)
      break
    }
  }
  let writer = match known_writer {
    Some(value) if value.history.length() > 0 => value
    _ => return Ok([])
  }
  let mut requested = false
  for offset in 0..<acknack.num_bits().reinterpret_as_int() {
    if discovery_sender_bitmap_contains(acknack.bitmap(), offset) &&
      acknack.bitmap_base() <= 0x7FFFFFFFFFFFFFFFL - offset.to_int64() {
      let sequence = acknack.bitmap_base() + offset.to_int64()
      if sequence < writer.next_sequence || writer.sequence_exhausted {
        requested = true
        break
      }
    }
  }
  if !requested {
    return Ok([])
  }
  let control = match self.control(reader_prefix, kind) {
    Some(value) => value
    None => return Ok([])
  }
  if !discovery_control_count_is_new(control.acknack_count, acknack.count()) {
    return Ok([])
  }
  control.acknack_count = Some(acknack.count())
  let outputs : Array[DiscoveryOutput] = []
  for offset in 0..<acknack.num_bits().reinterpret_as_int() {
    if !discovery_sender_bitmap_contains(acknack.bitmap(), offset) {
      continue
    }
    if acknack.bitmap_base() > 0x7FFFFFFFFFFFFFFFL - offset.to_int64() {
      continue
    }
    let sequence = acknack.bitmap_base() + offset.to_int64()
    let mut found = false
    for write in writer.history {
      if write.data.writer_sequence_number() != sequence {
        continue
      }
      found = true
      for message in self.data_messages(write) {
        outputs.push({
          message: message.with_destination_guid_prefix(reader_prefix),
          destination: source,
        })
      }
    }
    if !found && (sequence < writer.next_sequence || writer.sequence_exhausted) {
      outputs.push(self.gap_output(writer, sequence, reader_prefix, source))
    }
  }
  Ok(outputs)
}

///|
pub fn DiscoverySender::retransmit_nackfrag(
  self : DiscoverySender,
  reader_prefix : @core.GuidPrefix,
  nackfrag : @core.NackFragSubmessage,
  source : @core.Locator,
) -> Result[Array[DiscoveryOutput], String] {
  let kind = match
    SedpEndpointKind::from_builtin_writer_id(nackfrag.writer_id()) {
    Ok(value) => value
    Err(_) => return Ok([])
  }
  if nackfrag.reader_id() != kind.builtin_reader_id() &&
    nackfrag.reader_id() != @core.EntityId::unknown() {
    return Ok([])
  }
  let mut known_writer : DiscoveryWriter? = None
  for writer in self.writers {
    if writer.kind == kind {
      known_writer = Some(writer)
      break
    }
  }
  let writer = match known_writer {
    Some(value) if value.history.length() > 0 => value
    _ => return Ok([])
  }
  if !nackfrag.bitmap().any(fn(word) { word != 0U }) ||
    (
      nackfrag.writer_sequence_number() >= writer.next_sequence &&
      !writer.sequence_exhausted
    ) {
    return Ok([])
  }
  let control = match self.control(reader_prefix, kind) {
    Some(value) => value
    None => return Ok([])
  }
  if !discovery_control_count_is_new(control.nackfrag_count, nackfrag.count()) {
    return Ok([])
  }
  control.nackfrag_count = Some(nackfrag.count())
  let outputs : Array[DiscoveryOutput] = []
  let mut found = false
  for write in writer.history {
    if write.data.writer_sequence_number() != nackfrag.writer_sequence_number() {
      continue
    }
    found = true
    for offset in 0..<nackfrag.num_bits().reinterpret_as_int() {
      if !discovery_sender_bitmap_contains(nackfrag.bitmap(), offset) {
        continue
      }
      let number = nackfrag.bitmap_base().to_uint64() + offset.to_uint64()
      if number < 1UL || number > write.fragments.length().to_uint64() {
        continue
      }
      let fragment = write.fragments[number.to_int() - 1]
      outputs.push({
        message: fragment
        .to_message(
          self.participant.participant_guid().prefix(),
          self.participant.vendor_id(),
        )
        .with_destination_guid_prefix(reader_prefix),
        destination: source,
      })
    }
  }
  if !found &&
    (
      nackfrag.writer_sequence_number() < writer.next_sequence ||
      writer.sequence_exhausted
    ) {
    outputs.push(
      self.gap_output(
        writer,
        nackfrag.writer_sequence_number(),
        reader_prefix,
        source,
      ),
    )
  }
  Ok(outputs)
}

///|
/// A participant restart must be allowed to restart its control-message counts.
pub fn DiscoverySender::forget_remote_participant(
  self : DiscoverySender,
  prefix : @core.GuidPrefix,
) -> Unit {
  self.controls = self.controls.filter(fn(control) { control.prefix != prefix })
}

///|
fn DiscoverySender::heartbeats_for_writer(
  self : DiscoverySender,
  writer : DiscoveryWriter,
  remotes : Array[SpdpParticipantData],
) -> Array[DiscoveryOutput] {
  if writer.history.length() == 0 {
    return []
  }
  let kind = writer.kind
  let first = writer.history[0].data.writer_sequence_number()
  let last = writer.history[writer.history.length() - 1].data.writer_sequence_number()
  // Retained writes have positive, ordered sequences and nonempty fragments.
  let heartbeat = @core.HeartbeatSubmessage::new(
    kind.builtin_reader_id(),
    kind.builtin_writer_id(),
    first,
    last,
    writer.next_heartbeat,
  ).unwrap()
  let prefix = self.participant.participant_guid().prefix()
  let vendor = self.participant.vendor_id()
  let messages : Array[@core.Message] = []
  let mut previous = first
  for write in writer.history {
    let sequence = write.data.writer_sequence_number()
    if sequence - previous > 1L {
      let gap = @core.GapSubmessage::new(
        kind.builtin_reader_id(),
        kind.builtin_writer_id(),
        previous + 1L,
        sequence,
        0U,
        [],
      ).unwrap()
      messages.push(gap.to_message(prefix, vendor))
    }
    previous = sequence
  }
  messages.push(heartbeat.to_message(prefix, vendor))
  for write in writer.history {
    if write.fragments.length() == 0 {
      continue
    }
    let heartbeat_frag = @core.HeartbeatFragSubmessage::new(
      kind.builtin_reader_id(),
      kind.builtin_writer_id(),
      write.data.writer_sequence_number(),
      write.fragments.length().reinterpret_as_uint(),
      writer.next_heartbeat,
    ).unwrap()
    messages.push(heartbeat_frag.to_message(prefix, vendor))
  }
  let outputs : Array[DiscoveryOutput] = []
  for remote in remotes {
    if remote.participant_guid() == self.participant.participant_guid() {
      continue
    }
    let destinations = self.metatraffic_locators(remote)
    for destination in destinations {
      for message in messages {
        outputs.push({
          message: message.with_destination_guid_prefix(
            remote.participant_guid().prefix(),
          ),
          destination,
        })
      }
    }
  }
  writer.next_heartbeat += 1U
  outputs
}

///|
/// Re-advertise the complete retained range, including fragment counts, without
/// allocating a new sample sequence. Callers drive the periodic schedule.
pub fn DiscoverySender::heartbeats(
  self : DiscoverySender,
  remotes : Array[SpdpParticipantData],
) -> Array[DiscoveryOutput] {
  let outputs : Array[DiscoveryOutput] = []
  for writer in self.writers {
    for heartbeat in self.heartbeats_for_writer(writer, remotes) {
      outputs.push(heartbeat)
    }
  }
  outputs
}

///|
fn discovery_write_bytes(write : DiscoveryWrite) -> Int32 {
  let mut bytes = write.data.to_payload().length()
  for fragment in write.fragments {
    bytes += fragment.to_payload().length()
  }
  bytes
}

///|
fn DiscoverySender::gap_output(
  self : DiscoverySender,
  writer : DiscoveryWriter,
  sequence : Int64,
  reader_prefix : @core.GuidPrefix,
  destination : @core.Locator,
) -> DiscoveryOutput {
  let mut start = 1L
  let mut end = writer.next_sequence
  for write in writer.history {
    let retained_sequence = write.data.writer_sequence_number()
    if retained_sequence < sequence {
      start = retained_sequence + 1L
    }
    if retained_sequence > sequence {
      end = retained_sequence
      break
    }
  }
  let kind = writer.kind
  let gap = @core.GapSubmessage::new(
    kind.builtin_reader_id(),
    kind.builtin_writer_id(),
    start,
    end,
    0U,
    [],
  ).unwrap()
  {
    message: gap
    .to_message(
      self.participant.participant_guid().prefix(),
      self.participant.vendor_id(),
    )
    .with_destination_guid_prefix(reader_prefix),
    destination,
  }
}

///|
/// Replay the latest sample for every endpoint without allocating sequences.
/// Acknowledging another peer never removes transient-local discovery history.
pub fn DiscoverySender::replay_sedp(
  self : DiscoverySender,
  remote : SpdpParticipantData,
) -> Result[Array[DiscoveryOutput], String] {
  if remote.participant_guid() == self.participant.participant_guid() {
    return Ok([])
  }
  let destinations = self.metatraffic_locators(remote)
  if destinations.length() == 0 {
    return Err("the remote participant has no supported metatraffic locators")
  }
  let outputs : Array[DiscoveryOutput] = []
  for writer in self.writers {
    for write in writer.history {
      for destination in destinations {
        for message in self.data_messages(write) {
          outputs.push({
            message: message.with_destination_guid_prefix(
              remote.participant_guid().prefix(),
            ),
            destination,
          })
        }
      }
    }
    for heartbeat in self.heartbeats_for_writer(writer, [remote]) {
      outputs.push(heartbeat)
    }
  }
  Ok(outputs)
}
