///|
/// Minimal reliable RTPS reader state for ACKNACK generation.
///
/// UDP receive scheduling remains outside this type. The application feeds
/// decoded DATA samples to `accept_data` and a decoded HEARTBEAT to
/// `acknack_for_heartbeat`.
pub struct ReliableFragmentedSample {
  reader_id : EntityId
  writer_id : EntityId
  sequence_number : Int64
  data_flags : Byte
  fragment_size : Int32
  sample_size : Int32
  mut inline_qos : Bytes
  payload : Array[Byte]
  received : Array[Bool]
  mut received_count : Int32
}

///|
fn reliable_fragmented_sample_new(
  fragment : DataFragSubmessage,
) -> Result[ReliableFragmentedSample, String] {
  let sample_size = fragment.sample_size().reinterpret_as_int()
  let fragment_size = fragment.fragment_size().to_int()
  let total_fragments = (sample_size + fragment_size - 1) / fragment_size
  let payload : Array[Byte] = []
  let received : Array[Bool] = []
  for _ in 0..<sample_size {
    payload.push(0)
  }
  for _ in 0..<total_fragments {
    received.push(false)
  }
  Ok({
    reader_id: fragment.reader_id(),
    writer_id: fragment.writer_id(),
    sequence_number: fragment.writer_sequence_number(),
    data_flags: if (fragment.flags() & DATA_FRAG_FLAG_KEY) != 0 {
      DATA_FLAG_KEY
    } else {
      DATA_FLAG_DATA
    },
    fragment_size,
    sample_size,
    inline_qos: fragment.inline_qos(),
    payload,
    received,
    received_count: 0,
  })
}

///|
fn ReliableFragmentedSample::accept_fragment(
  self : ReliableFragmentedSample,
  fragment : DataFragSubmessage,
) -> Result[Unit, String] {
  if fragment.fragment_size().to_int() != self.fragment_size ||
    fragment.sample_size().reinterpret_as_int() != self.sample_size ||
    ((fragment.flags() & DATA_FRAG_FLAG_KEY) != 0) !=
    ((self.data_flags & DATA_FLAG_KEY) != 0) {
    return Err("RTPS DATA_FRAG metadata changed within one sample")
  }
  let starting = fragment.fragment_starting_number().reinterpret_as_int()
  let count = fragment.fragments_in_submessage().to_int()
  let last = starting + count - 1
  let total = self.received.length()
  let payload = fragment.serialized_payload()
  let payload_offset = (starting - 1) * self.fragment_size
  let max_payload_length = self.fragment_size * count
  if starting < 1 ||
    last > total ||
    payload.length() == 0 ||
    payload.length() > max_payload_length ||
    payload_offset + payload.length() > self.sample_size {
    return Err("RTPS DATA_FRAG payload has an invalid fragment range")
  }
  if payload.length() < max_payload_length &&
    (last != total || payload.length() != self.sample_size - payload_offset) {
    return Err("only the final RTPS DATA_FRAG may be short")
  }
  if self.inline_qos.length() == 0 && fragment.inline_qos().length() > 0 {
    self.inline_qos = fragment.inline_qos()
  }
  for i in 0..<payload.length() {
    self.payload[payload_offset + i] = payload[i]
  }
  for offset in 0..<count {
    let index = starting - 1 + offset
    if !self.received[index] {
      self.received[index] = true
      self.received_count += 1
    }
  }
  Ok(())
}

///|
fn ReliableFragmentedSample::is_complete(
  self : ReliableFragmentedSample,
) -> Bool {
  self.received_count == self.received.length()
}

///|
fn ReliableFragmentedSample::to_data(
  self : ReliableFragmentedSample,
) -> DataSubmessage {
  let data = DataSubmessage::new(
    self.reader_id,
    self.writer_id,
    self.sequence_number,
    Bytes::from_array(self.payload),
  )
  let data = if (self.data_flags & DATA_FLAG_KEY) != 0 {
    data.with_key(data.serialized_payload())
  } else {
    data
  }
  if self.inline_qos.length() == 0 {
    data
  } else {
    data.with_inline_qos(self.inline_qos)
  }
}

///|
/// Reliable RTPS reader state for one remote writer.
pub struct ReliableDataReader {
  reader_id : EntityId
  writer_id : EntityId
  mut next_acknack_count : UInt32
  mut next_nackfrag_count : UInt32
  mut samples : Array[Int64]
  mut gaps : Array[GapSubmessage]
  mut fragments : Array[ReliableFragmentedSample]
  mut acknowledged_through : Int64
  mut accepted_sample_count : Int32
}

///|
/// Create a reliable reader for one remote RTPS writer.
pub fn ReliableDataReader::new(
  reader_id : EntityId,
  writer_id : EntityId,
) -> ReliableDataReader {
  {
    reader_id,
    writer_id,
    next_acknack_count: 1U,
    next_nackfrag_count: 1U,
    samples: [],
    gaps: [],
    fragments: [],
    acknowledged_through: 0L,
    accepted_sample_count: 0,
  }
}

///|
/// Return the next ACKNACK count value.
pub fn ReliableDataReader::next_acknack_count(
  self : ReliableDataReader,
) -> UInt32 {
  self.next_acknack_count
}

///|
/// Return the next NACKFRAG count value.
pub fn ReliableDataReader::next_nackfrag_count(
  self : ReliableDataReader,
) -> UInt32 {
  self.next_nackfrag_count
}

///|
/// Return the number of DATA samples accepted so far.
pub fn ReliableDataReader::sample_count(self : ReliableDataReader) -> Int32 {
  self.accepted_sample_count
}

///|
/// Check received, irrelevant, or cumulatively acknowledged sequence state.
pub fn ReliableDataReader::has_received_sequence(
  self : ReliableDataReader,
  sequence_number : Int64,
) -> Bool {
  sequence_number <= self.acknowledged_through ||
  reliable_reader_has_sequence(self.samples, sequence_number) ||
  reliable_reader_gap_contains_sequence(self.gaps, sequence_number)
}

///|
/// Release receive state covered by a successful cumulative ACKNACK base.
fn ReliableDataReader::advance_acknowledged_through(
  self : ReliableDataReader,
  sequence_number : Int64,
) -> Unit {
  if sequence_number <= self.acknowledged_through {
    return
  }
  self.acknowledged_through = sequence_number
  let retained_samples : Array[Int64] = []
  for sample_sequence_number in self.samples {
    if sample_sequence_number > sequence_number {
      retained_samples.push(sample_sequence_number)
    }
  }
  self.samples = retained_samples
  let retained_fragments : Array[ReliableFragmentedSample] = []
  for fragment in self.fragments {
    if fragment.sequence_number > sequence_number {
      retained_fragments.push(fragment)
    }
  }
  self.fragments = retained_fragments
  let retained_gaps : Array[GapSubmessage] = []
  for gap in self.gaps {
    if !reliable_reader_gap_is_covered_through(gap, sequence_number) {
      retained_gaps.push(gap)
    }
  }
  self.gaps = retained_gaps
}

///|
/// Accept a DATA sample addressed to this reader and writer.
pub fn ReliableDataReader::accept_data(
  self : ReliableDataReader,
  data : DataSubmessage,
) -> Result[Unit, String] {
  if data.reader_id() != self.reader_id &&
    data.reader_id() != EntityId::unknown() {
    return Err("the DATA sample targets a different RTPS reader")
  }
  if data.writer_id() != self.writer_id {
    return Err("the DATA sample comes from a different RTPS writer")
  }
  if self.has_received_sequence(data.writer_sequence_number()) {
    return Ok(())
  }
  self.samples.push(data.writer_sequence_number())
  self.accepted_sample_count += 1
  Ok(())
}

///|
/// Accept a GAP addressed to this reader and writer.
pub fn ReliableDataReader::accept_gap(
  self : ReliableDataReader,
  gap : GapSubmessage,
) -> Result[Unit, String] {
  if gap.reader_id() != self.reader_id && gap.reader_id() != EntityId::unknown() {
    return Err("the GAP targets a different RTPS reader")
  }
  if gap.writer_id() != self.writer_id {
    return Err("the GAP comes from a different RTPS writer")
  }
  if reliable_reader_gap_is_covered_through(gap, self.acknowledged_through) {
    return Ok(())
  }
  self.gaps.push(gap)
  let retained_fragments : Array[ReliableFragmentedSample] = []
  for fragment in self.fragments {
    if !gap.contains_sequence(fragment.sequence_number) {
      retained_fragments.push(fragment)
    }
  }
  self.fragments = retained_fragments
  Ok(())
}

///|
/// Accept one DATA_FRAG and return a reassembled DATA when complete.
pub fn ReliableDataReader::accept_data_frag(
  self : ReliableDataReader,
  fragment : DataFragSubmessage,
) -> Result[DataSubmessage?, String] {
  if fragment.reader_id() != self.reader_id &&
    fragment.reader_id() != EntityId::unknown() {
    return Err("the DATA_FRAG targets a different RTPS reader")
  }
  if fragment.writer_id() != self.writer_id {
    return Err("the DATA_FRAG comes from a different RTPS writer")
  }
  if self.has_received_sequence(fragment.writer_sequence_number()) {
    return Ok(None)
  }
  let mut index : Int32? = None
  for i in 0..<self.fragments.length() {
    if self.fragments[i].sequence_number == fragment.writer_sequence_number() {
      index = Some(i)
      break
    }
  }
  let index = match index {
    Some(value) => value
    None => {
      let sample = match reliable_fragmented_sample_new(fragment) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      self.fragments.push(sample)
      self.fragments.length() - 1
    }
  }
  match self.fragments[index].accept_fragment(fragment) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  if !self.fragments[index].is_complete() {
    return Ok(None)
  }
  let data = self.fragments[index].to_data()
  let retained_fragments : Array[ReliableFragmentedSample] = []
  for i in 0..<self.fragments.length() {
    if i != index {
      retained_fragments.push(self.fragments[i])
    }
  }
  self.fragments = retained_fragments
  self.samples.push(data.writer_sequence_number())
  self.accepted_sample_count += 1
  Ok(Some(data))
}

///|
/// Build NACK_FRAG windows for fragments missing from a HEARTBEAT_FRAG range.
/// FragmentNumberSet has the same 256-bit limit as SequenceNumberSet.
pub fn ReliableDataReader::nackfrags_for_heartbeat_frag(
  self : ReliableDataReader,
  heartbeat : HeartbeatFragSubmessage,
) -> Result[Array[NackFragSubmessage], String] {
  if heartbeat.reader_id() != self.reader_id &&
    heartbeat.reader_id() != EntityId::unknown() {
    return Err("the HEARTBEAT_FRAG targets a different RTPS reader")
  }
  if heartbeat.writer_id() != self.writer_id {
    return Err("the HEARTBEAT_FRAG comes from a different RTPS writer")
  }
  if self.has_received_sequence(heartbeat.writer_sequence_number()) {
    return Ok([])
  }
  let mut fragmented_sample : ReliableFragmentedSample? = None
  for fragment in self.fragments {
    if fragment.sequence_number == heartbeat.writer_sequence_number() {
      fragmented_sample = Some(fragment)
      break
    }
  }
  let result : Array[NackFragSubmessage] = []
  let mut bitmap_base = 1U
  while bitmap_base <= heartbeat.last_fragment_number() {
    let remaining = (heartbeat.last_fragment_number() - bitmap_base + 1U).reinterpret_as_int()
    let num_bits = if remaining > 256 { 256 } else { remaining }
    let word_count = (num_bits + 31) / 32
    let bitmap : Array[UInt32] = []
    for _ in 0..<word_count {
      bitmap.push(0U)
    }
    for offset in 0..<num_bits {
      let fragment_index = bitmap_base.reinterpret_as_int() - 1 + offset
      let received = match fragmented_sample {
        Some(sample) if fragment_index < sample.received.length() =>
          sample.received[fragment_index]
        _ => false
      }
      if received {
        continue
      }
      let word_index = offset / 32
      let bit_index = offset % 32
      bitmap[word_index] = bitmap[word_index] | (0x80000000U >> bit_index)
    }
    let nackfrag = match
      NackFragSubmessage::new(
        self.reader_id,
        self.writer_id,
        heartbeat.writer_sequence_number(),
        bitmap_base,
        num_bits.reinterpret_as_uint(),
        bitmap,
        self.next_nackfrag_count,
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    result.push(nackfrag)
    self.next_nackfrag_count += 1U
    bitmap_base += num_bits.reinterpret_as_uint()
  }
  Ok(result)
}

///|
/// Build one NACK_FRAG for the first window of a HEARTBEAT_FRAG range.
pub fn ReliableDataReader::nackfrag_for_heartbeat_frag(
  self : ReliableDataReader,
  heartbeat : HeartbeatFragSubmessage,
) -> Result[NackFragSubmessage, String] {
  let nackfrags = match self.nackfrags_for_heartbeat_frag(heartbeat) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if nackfrags.length() == 0 {
    return Err("the HEARTBEAT_FRAG fragment range is empty")
  }
  if nackfrags.length() > 1 {
    self.next_nackfrag_count -= (nackfrags.length() - 1).reinterpret_as_uint()
  }
  Ok(nackfrags[0])
}

///|
fn reliable_reader_has_sequence(
  samples : Array[Int64],
  sequence_number : Int64,
) -> Bool {
  for sample in samples {
    if sample == sequence_number {
      return true
    }
  }
  false
}

///|
/// Check whether a GAP's entire sequence range is cumulatively acknowledged.
fn reliable_reader_gap_is_covered_through(
  gap : GapSubmessage,
  acknowledged_through : Int64,
) -> Bool {
  let bitmap_base = gap.gap_list_base()
  let num_bits = gap.gap_list_num_bits().to_int64()
  if num_bits == 0L {
    return acknowledged_through >= bitmap_base - 1L
  }
  acknowledged_through >= bitmap_base &&
  acknowledged_through - bitmap_base >= num_bits - 1L
}

///|
fn reliable_reader_gap_contains_sequence(
  gaps : Array[GapSubmessage],
  sequence_number : Int64,
) -> Bool {
  for gap in gaps {
    if gap.contains_sequence(sequence_number) {
      return true
    }
  }
  false
}

///|
/// Build an ACKNACK whose base is the first missing sample in the heartbeat.
/// RTPS SequenceNumberSet carries at most 256 bits; later gaps are requested
/// after an ensuing HEARTBEAT advances the first missing sequence number.
pub fn ReliableDataReader::acknacks_for_heartbeat(
  self : ReliableDataReader,
  heartbeat : HeartbeatSubmessage,
) -> Result[Array[AckNackSubmessage], String] {
  if heartbeat.reader_id() != self.reader_id &&
    heartbeat.reader_id() != EntityId::unknown() {
    return Err("the HEARTBEAT targets a different RTPS reader")
  }
  if heartbeat.writer_id() != self.writer_id {
    return Err("the HEARTBEAT comes from a different RTPS writer")
  }
  let last_sequence_number = heartbeat.last_sequence_number()
  let mut first_missing : Int64? = None
  let mut sequence_number = heartbeat.first_sequence_number()
  while sequence_number <= last_sequence_number && first_missing is None {
    // GAP's contiguous prefix may span almost the entire Int64 range. Jump
    // over it rather than scanning every sequence; inspect bitmap holes below.
    let mut covered_through = self.acknowledged_through
    for gap in self.gaps {
      if gap.gap_start() <= sequence_number &&
        sequence_number < gap.gap_list_base() {
        let end = gap.gap_list_base() - 1L
        if end > covered_through {
          covered_through = end
        }
      }
    }
    if covered_through >= sequence_number {
      if covered_through >= last_sequence_number {
        break
      }
      sequence_number = covered_through + 1L
    } else if !self.has_received_sequence(sequence_number) {
      first_missing = Some(sequence_number)
    } else if sequence_number < last_sequence_number {
      sequence_number += 1L
    } else {
      break
    }
  }
  let (bitmap_base, range) = match first_missing {
    Some(value) => {
      let remaining = last_sequence_number - value
      (value, if remaining >= 255L { 256 } else { remaining.to_int() + 1 })
    }
    None if last_sequence_number == 0x7FFFFFFFFFFFFFFFL =>
      (last_sequence_number, 1)
    None => (last_sequence_number + 1L, 0)
  }
  let word_count = (range + 31) / 32
  let bitmap : Array[UInt32] = []
  for _ in 0..<word_count {
    bitmap.push(0U)
  }
  for offset in 0..<range {
    let sequence_number = bitmap_base + offset.to_int64()
    if self.has_received_sequence(sequence_number) {
      continue
    }
    let word_index = offset / 32
    let bit_index = offset % 32
    bitmap[word_index] = bitmap[word_index] | (0x80000000U >> bit_index)
  }
  let acknack = match
    AckNackSubmessage::new(
      self.reader_id,
      self.writer_id,
      bitmap_base,
      range.reinterpret_as_uint(),
      bitmap,
      self.next_acknack_count,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  self.next_acknack_count += 1U
  self.advance_acknowledged_through(bitmap_base - 1L)
  Ok([acknack])
}

///|
/// Build one ACKNACK for the first window of a HEARTBEAT range.
pub fn ReliableDataReader::acknack_for_heartbeat(
  self : ReliableDataReader,
  heartbeat : HeartbeatSubmessage,
) -> Result[AckNackSubmessage, String] {
  let acknacks = match self.acknacks_for_heartbeat(heartbeat) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if acknacks.length() == 0 {
    return Err("the HEARTBEAT sequence range is empty")
  }
  Ok(acknacks[0])
}

///|
/// Best-effort sends no ACKNACK, so advance the shared reader state's cumulative
/// cutoff locally. Release an incomplete sample once DATA completes it as well.
pub fn ReliableDataReader::prune_best_effort_receive_state(
  self : ReliableDataReader,
  sequence : Int64,
) -> Unit {
  self.advance_acknowledged_through(sequence - 256L)
  let retained : Array[ReliableFragmentedSample] = []
  for sample in self.fragments {
    if !self.has_received_sequence(sample.sequence_number) {
      retained.push(sample)
    }
  }
  self.fragments = retained
}

///|
/// Reject oversized samples before allocating and evict the oldest incomplete
/// samples when the count or payload budget is exhausted.
pub fn ReliableDataReader::accept_best_effort_fragment(
  self : ReliableDataReader,
  fragment : DataFragSubmessage,
) -> Result[DataSubmessage?, String] {
  let sequence = fragment.writer_sequence_number()
  if (
      fragment.reader_id() != self.reader_id &&
      fragment.reader_id() != EntityId::unknown()
    ) ||
    fragment.writer_id() != self.writer_id ||
    self.has_received_sequence(sequence) ||
    fragment.sample_size() > 16U * 1024U * 1024U {
    return Ok(None)
  }
  let mut already_pending = false
  for sample in self.fragments {
    if sample.sequence_number == sequence {
      already_pending = true
      break
    }
  }
  if !already_pending {
    while true {
      let mut payload_bytes = fragment.sample_size().reinterpret_as_int()
      let mut oldest_index = 0
      for index in 0..<self.fragments.length() {
        let sample = self.fragments[index]
        payload_bytes += sample.sample_size
        if sample.sequence_number < self.fragments[oldest_index].sequence_number {
          oldest_index = index
        }
      }
      if self.fragments.length() < 4 && payload_bytes <= 16 * 1024 * 1024 {
        break
      }
      let oldest = self.fragments[oldest_index]
      if sequence <= oldest.sequence_number {
        return Ok(None)
      }
      let retained : Array[ReliableFragmentedSample] = []
      for sample in self.fragments {
        if sample.sequence_number != oldest.sequence_number {
          retained.push(sample)
        }
      }
      self.fragments = retained
    }
  }
  match self.accept_data_frag(fragment) {
    Ok(data) => {
      self.prune_best_effort_receive_state(sequence)
      Ok(data)
    }
    Err(message) => Err(message)
  }
}

///|
/// Incomplete payload bytes plus eight bytes per fragment-presence slot.
/// Allows callers to enforce an aggregate reassembly budget before allocation.
pub fn ReliableDataReader::fragment_receive_usage(
  self : ReliableDataReader,
) -> (Int32, Int32) {
  let mut bytes = 0
  for sample in self.fragments {
    bytes += sample.sample_size + sample.received.length() * 8
  }
  (self.fragments.length(), bytes)
}

///|
pub fn ReliableDataReader::has_incomplete_fragment(
  self : ReliableDataReader,
  sequence : Int64,
) -> Bool {
  self.fragments.any(fn(sample) { sample.sequence_number == sequence })
}
