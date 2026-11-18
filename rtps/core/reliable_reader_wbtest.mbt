///|
test "best effort fragment completions keep bounded sample history" {
  let reader_id = EntityId::unknown()
  let writer_id = EntityId::new(b"abc", 0xC2).unwrap()
  let reader = ReliableDataReader::new(reader_id, writer_id)
  for sequence in 1..<=4096 {
    for number in 1..<=2 {
      let fragment = DataFragSubmessage::new(
        reader_id,
        writer_id,
        sequence.to_int64(),
        number.reinterpret_as_uint(),
        (1 : Int32).to_uint16(),
        (1 : Int32).to_uint16(),
        2U,
        b"a",
      ).unwrap()
      let result = reader.accept_best_effort_fragment(fragment).unwrap()
      assert_eq(result is Some(_), number == 2)
      assert_true(reader.samples.length() <= 256)
      assert_true(reader.fragments.length() <= 1)
      assert_eq(reader.gaps.length(), 0)
    }
  }
  assert_eq(reader.fragments.length(), 0)
  assert_eq(reader.samples.length(), 256)
  assert_eq(reader.next_acknack_count(), 1U)
  assert_eq(reader.next_nackfrag_count(), 1U)
}

///|
test "best-effort eviction ignores remaining fragments of the evicted sample" {
  let reader_id = EntityId::unknown()
  let writer_id = EntityId::new(b"abc", 0xC2).unwrap()
  let reader = ReliableDataReader::new(reader_id, writer_id)
  for sequence in 1..<5 {
    let fragment = DataFragSubmessage::new(
      reader_id,
      writer_id,
      sequence.to_int64(),
      1U,
      1U.to_uint16(),
      4U.to_uint16(),
      8U,
      b"abcd",
    ).unwrap()
    assert_eq(reader.accept_best_effort_fragment(fragment), Ok(None))
  }
  assert_eq(reader.fragments.length(), 4)
  let fifth = DataFragSubmessage::new(
    reader_id,
    writer_id,
    5L,
    1U,
    1U.to_uint16(),
    4U.to_uint16(),
    8U,
    b"abcd",
  ).unwrap()
  assert_eq(reader.accept_best_effort_fragment(fifth), Ok(None))
  assert_eq(reader.fragments.length(), 4)
  assert_eq(reader.fragments[0].sequence_number, 2L)
  assert_true(reader.abandoned_fragments.contains(1L))
  let second_fragment = DataFragSubmessage::new(
    reader_id,
    writer_id,
    2L,
    2U,
    1U.to_uint16(),
    4U.to_uint16(),
    8U,
    b"efgh",
  ).unwrap()
  let completed = reader.accept_best_effort_fragment(second_fragment).unwrap()
  assert_true(completed is Some(_))
  assert_eq(reader.fragments.length(), 3)
  // The evicted sequence now has room again, but its remaining fragments must
  // not allocate a new reassembly buffer.
  let late = DataFragSubmessage::new(
    reader_id,
    writer_id,
    1L,
    1U,
    1U.to_uint16(),
    4U.to_uint16(),
    8U,
    b"abcd",
  ).unwrap()
  assert_eq(reader.accept_best_effort_fragment(late), Ok(None))
  assert_eq(reader.fragments.length(), 3)
}

///|
test "reliable reader rejects oversized fragmented samples before allocation" {
  let reader_id = EntityId::unknown()
  let writer_id = EntityId::new(b"abc", 0xC2).unwrap()
  let reader = ReliableDataReader::new(reader_id, writer_id)
  let oversized = DataFragSubmessage::new(
    reader_id,
    writer_id,
    1L,
    1U,
    1U.to_uint16(),
    4U.to_uint16(),
    (RELIABLE_READER_MAX_FRAGMENTED_SAMPLE_SIZE + 1).reinterpret_as_uint(),
    b"abcd",
  ).unwrap()
  assert_eq(reader.accept_data_frag(oversized), Ok(None))
  assert_eq(reader.fragments.length(), 0)
}

///|
test "reliable reader rejects fragmented samples with too many fragments" {
  let reader_id = EntityId::unknown()
  let writer_id = EntityId::new(b"abc", 0xC2).unwrap()
  let reader = ReliableDataReader::new(reader_id, writer_id)
  let fragment = DataFragSubmessage::new(
    reader_id,
    writer_id,
    1L,
    1U,
    1U.to_uint16(),
    1U.to_uint16(),
    2U * 1024U * 1024U,
    b"a",
  ).unwrap()
  assert_eq(reader.accept_data_frag(fragment), Ok(None))
  assert_eq(reader.fragments.length(), 0)
}

///|
test "reliable reader bounds the number of incomplete fragmented samples" {
  let reader_id = EntityId::unknown()
  let writer_id = EntityId::new(b"abc", 0xC2).unwrap()
  let reader = ReliableDataReader::new(reader_id, writer_id)
  for sequence in 1..<=RELIABLE_READER_MAX_FRAGMENTED_SAMPLES {
    let fragment = DataFragSubmessage::new(
      reader_id,
      writer_id,
      sequence.to_int64(),
      1U,
      1U.to_uint16(),
      4U.to_uint16(),
      8U,
      b"abcd",
    ).unwrap()
    assert_eq(reader.accept_data_frag(fragment), Ok(None))
  }
  assert_eq(reader.fragments.length(), RELIABLE_READER_MAX_FRAGMENTED_SAMPLES)
  let extra = DataFragSubmessage::new(
    reader_id,
    writer_id,
    (RELIABLE_READER_MAX_FRAGMENTED_SAMPLES + 1).to_int64(),
    1U,
    1U.to_uint16(),
    4U.to_uint16(),
    8U,
    b"abcd",
  ).unwrap()
  assert_eq(reader.accept_data_frag(extra), Ok(None))
  assert_eq(reader.fragments.length(), RELIABLE_READER_MAX_FRAGMENTED_SAMPLES)
}
