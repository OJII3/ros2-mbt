///|
/// Minimal reliable RTPS reader state for ACKNACK generation.
///
/// UDP receive scheduling remains outside this type. The application feeds
/// decoded DATA samples to `accept_data` and a decoded HEARTBEAT to
/// `acknack_for_heartbeat`.
pub struct ReliableDataReader {
  reader_id : @rtps.EntityId
  writer_id : @rtps.EntityId
  mut next_acknack_count : UInt
  samples : Array[@rtps.DataSubmessage]
}

///|
/// Create a reliable reader for one remote RTPS writer.
pub fn ReliableDataReader::new(
  reader_id : @rtps.EntityId,
  writer_id : @rtps.EntityId,
) -> ReliableDataReader {
  { reader_id, writer_id, next_acknack_count: 1U, samples: [], }
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
    if reliable_reader_has_sequence(self.samples, sequence_number) {
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
