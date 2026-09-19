///|
/// Minimal reliable RTPS reader state for ACKNACK generation.
///
/// UDP receive scheduling remains outside this type. The application feeds
/// decoded DATA samples to `accept_data` and a decoded HEARTBEAT to
/// `acknack_for_heartbeat`.
struct ReliableFragmentedSample {
  reader_id : @rtps.EntityId
  writer_id : @rtps.EntityId
  sequence_number : Int64
  fragment_size : Int
  sample_size : Int
  mut inline_qos : Bytes
  payload : Array[Byte]
  received : Array[Bool]
  mut received_count : Int
}

///|
fn reliable_fragmented_sample_new(
  fragment : @rtps.DataFragSubmessage,
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
  fragment : @rtps.DataFragSubmessage,
) -> Result[Unit, String] {
  if fragment.fragment_size().to_int() != self.fragment_size ||
    fragment.sample_size().reinterpret_as_int() != self.sample_size {
    return Err("RTPS DATA_FRAG metadata changed within one sample")
  }
  let starting = fragment.fragment_starting_number().reinterpret_as_int()
  let count = fragment.fragments_in_submessage().to_int()
  let last = starting + count - 1
  let total = self.received.length()
  let payload = fragment.serialized_payload()
  let payload_offset = (starting - 1) * self.fragment_size
  let max_payload_length = self.fragment_size * count
  if starting < 1 || last > total || payload.length() == 0 ||
    payload.length() > max_payload_length ||
    payload_offset + payload.length() > self.sample_size {
    return Err("RTPS DATA_FRAG payload has an invalid fragment range")
  }
  if payload.length() < max_payload_length &&
    (last != total ||
      payload.length() != self.sample_size - payload_offset) {
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
) -> @rtps.DataSubmessage {
  let data = @rtps.DataSubmessage::new(
    self.reader_id,
    self.writer_id,
    self.sequence_number,
    Bytes::from_array(self.payload),
  )
  if self.inline_qos.length() == 0 {
    data
  } else {
    data.with_inline_qos(self.inline_qos)
  }
}

pub struct ReliableDataReader {
  reader_id : @rtps.EntityId
  writer_id : @rtps.EntityId
  mut next_acknack_count : UInt
  samples : Array[@rtps.DataSubmessage]
  gaps : Array[@rtps.GapSubmessage]
  fragments : Array[ReliableFragmentedSample]
}

///|
/// Create a reliable reader for one remote RTPS writer.
pub fn ReliableDataReader::new(
  reader_id : @rtps.EntityId,
  writer_id : @rtps.EntityId,
) -> ReliableDataReader {
  {
    reader_id,
    writer_id,
    next_acknack_count: 1U,
    samples: [],
    gaps: [],
    fragments: [],
  }
}

///|
pub fn ReliableDataReader::next_acknack_count(
  self : ReliableDataReader,
) -> UInt {
  self.next_acknack_count
}

///|
/// Return the number of DATA samples accepted so far.
pub fn ReliableDataReader::sample_count(self : ReliableDataReader) -> Int {
  self.samples.length()
}

///|
/// Accept a DATA sample addressed to this reader and writer.
pub fn ReliableDataReader::accept_data(
  self : ReliableDataReader,
  data : @rtps.DataSubmessage,
) -> Result[Unit, String] {
  if data.reader_id() != self.reader_id &&
    data.reader_id() != @rtps.EntityId::unknown() {
    return Err("the DATA sample targets a different RTPS reader")
  }
  if data.writer_id() != self.writer_id {
    return Err("the DATA sample comes from a different RTPS writer")
  }
  for sample in self.samples {
    if sample.writer_sequence_number() == data.writer_sequence_number() {
      return Ok(())
    }
  }
  self.samples.push(data)
  Ok(())
}

///|
/// Accept a GAP addressed to this reader and writer.
pub fn ReliableDataReader::accept_gap(
  self : ReliableDataReader,
  gap : @rtps.GapSubmessage,
) -> Result[Unit, String] {
  if gap.reader_id() != self.reader_id &&
    gap.reader_id() != @rtps.EntityId::unknown() {
    return Err("the GAP targets a different RTPS reader")
  }
  if gap.writer_id() != self.writer_id {
    return Err("the GAP comes from a different RTPS writer")
  }
  self.gaps.push(gap)
  Ok(())
}

///|
/// Accept one DATA_FRAG and return a reassembled DATA when complete.
pub fn ReliableDataReader::accept_data_frag(
  self : ReliableDataReader,
  fragment : @rtps.DataFragSubmessage,
) -> Result[@rtps.DataSubmessage?, String] {
  if fragment.reader_id() != self.reader_id &&
    fragment.reader_id() != @rtps.EntityId::unknown() {
    return Err("the DATA_FRAG targets a different RTPS reader")
  }
  if fragment.writer_id() != self.writer_id {
    return Err("the DATA_FRAG comes from a different RTPS writer")
  }
  if reliable_reader_has_sequence(self.samples, fragment.writer_sequence_number()) {
    return Ok(None)
  }
  let mut index : Int? = None
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
  self.samples.push(data)
  Ok(Some(data))
}

///|
fn reliable_reader_has_sequence(
  samples : Array[@rtps.DataSubmessage],
  sequence_number : Int64,
) -> Bool {
  for sample in samples {
    if sample.writer_sequence_number() == sequence_number {
      return true
    }
  }
  false
}

///|
fn reliable_reader_gap_contains_sequence(
  gaps : Array[@rtps.GapSubmessage],
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
/// Build an ACKNACK whose set bits identify samples missing from a heartbeat.
pub fn ReliableDataReader::acknack_for_heartbeat(
  self : ReliableDataReader,
  heartbeat : @rtps.HeartbeatSubmessage,
) -> Result[@rtps.AckNackSubmessage, String] {
  if heartbeat.reader_id() != self.reader_id &&
    heartbeat.reader_id() != @rtps.EntityId::unknown() {
    return Err("the HEARTBEAT targets a different RTPS reader")
  }
  if heartbeat.writer_id() != self.writer_id {
    return Err("the HEARTBEAT comes from a different RTPS writer")
  }
  let range = (heartbeat.last_sequence_number() -
  heartbeat.first_sequence_number() +
  1L).to_int()
  if range <= 0 || range > 256 {
    return Err("the HEARTBEAT sequence range is outside ACKNACK bitmap limits")
  }
  let word_count = (range + 31) / 32
  let bitmap : Array[UInt] = []
  for _ in 0..<word_count {
    bitmap.push(0U)
  }
  for offset in 0..<range {
    let sequence_number = heartbeat.first_sequence_number() + offset.to_int64()
    if reliable_reader_has_sequence(self.samples, sequence_number) ||
      reliable_reader_gap_contains_sequence(self.gaps, sequence_number) {
      continue
    }
    let word_index = offset / 32
    let bit_index = offset % 32
    bitmap[word_index] = bitmap[word_index] | (0x80000000U >> bit_index)
  }
  let result = match
    @rtps.AckNackSubmessage::new(
      self.reader_id,
      self.writer_id,
      heartbeat.first_sequence_number(),
      range.reinterpret_as_uint(),
      bitmap,
      self.next_acknack_count,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  self.next_acknack_count += 1U
  Ok(result)
}
