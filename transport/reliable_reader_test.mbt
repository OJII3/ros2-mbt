///|
test "reliable reader creates an ACKNACK for missing samples" {
  let reader_id = match @rtps.EntityId::new(b"rdr", 0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match @rtps.EntityId::new(b"wrt", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let reader = ReliableDataReader::new(reader_id, writer_id)
  let first = @rtps.DataSubmessage::new(reader_id, writer_id, 1L, b"first")
  match reader.accept_data(first) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let heartbeat = match
    @rtps.HeartbeatSubmessage::new(reader_id, writer_id, 1L, 3L, 1U) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let acknack = match reader.acknack_for_heartbeat(heartbeat) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(reader.sample_count(), 1)
  assert_eq(reader.next_acknack_count(), 2U)
  assert_eq(acknack.bitmap_base(), 1L)
  assert_eq(acknack.num_bits(), 3U)
  assert_eq(acknack.bitmap(), [0x60000000U])
  assert_eq(acknack.count(), 1U)
}

///|
test "reliable reader splits a large HEARTBEAT into ACKNACK windows" {
  let reader_id = @rtps.EntityId::new(b"rdr", 0xC7).unwrap()
  let writer_id = @rtps.EntityId::new(b"wrt", 0xC2).unwrap()
  let reader = ReliableDataReader::new(reader_id, writer_id)
  let heartbeat = @rtps.HeartbeatSubmessage::new(
    reader_id,
    writer_id,
    1L,
    300L,
    1U,
  ).unwrap()
  let acknacks = reader.acknacks_for_heartbeat(heartbeat).unwrap()
  assert_eq(acknacks.length(), 2)
  assert_eq(acknacks[0].bitmap_base(), 1L)
  assert_eq(acknacks[0].num_bits(), 256U)
  assert_eq(acknacks[0].count(), 1U)
  assert_eq(acknacks[1].bitmap_base(), 257L)
  assert_eq(acknacks[1].num_bits(), 44U)
  assert_eq(acknacks[1].count(), 2U)
  assert_eq(reader.next_acknack_count(), 3U)
}

///|
test "reliable reader accepts a multicast HEARTBEAT with unknown reader" {
  let reader_id = @rtps.EntityId::new(b"rdr", 0xC7).unwrap()
  let writer_id = @rtps.EntityId::new(b"wrt", 0xC2).unwrap()
  let reader = ReliableDataReader::new(reader_id, writer_id)
  let heartbeat = @rtps.HeartbeatSubmessage::new(
    @rtps.EntityId::unknown(),
    writer_id,
    1L,
    1L,
    1U,
  ).unwrap()
  let acknack = reader.acknack_for_heartbeat(heartbeat).unwrap()
  assert_eq(acknack.reader_id(), reader_id)
  assert_eq(acknack.writer_id(), writer_id)
  assert_eq(acknack.num_bits(), 1U)
}

///|
test "reliable reader accepts DATA with an unknown reader ID" {
  let reader_id = @rtps.EntityId::new(b"rdr", 0xC7).unwrap()
  let writer_id = @rtps.EntityId::new(b"wrt", 0xC2).unwrap()
  let reader = ReliableDataReader::new(reader_id, writer_id)
  let data = @rtps.DataSubmessage::new(
    @rtps.EntityId::unknown(),
    writer_id,
    1L,
    b"multicast payload",
  )
  assert_true(reader.accept_data(data) is Ok(_))
  assert_eq(reader.sample_count(), 1)
}

///|
test "reliable reader does not request sequences declared by GAP" {
  let reader_id = @rtps.EntityId::new(b"rdr", 0xC7).unwrap()
  let writer_id = @rtps.EntityId::new(b"wrt", 0xC2).unwrap()
  let reader = ReliableDataReader::new(reader_id, writer_id)
  let gap = @rtps.GapSubmessage::new(
    reader_id,
    writer_id,
    2L,
    4L,
    5U,
    [0x90000000U],
  ).unwrap()
  reader.accept_gap(gap).unwrap()
  let heartbeat = @rtps.HeartbeatSubmessage::new(
    reader_id,
    writer_id,
    1L,
    5L,
    1U,
  ).unwrap()
  let acknack = reader.acknack_for_heartbeat(heartbeat).unwrap()
  assert_eq(acknack.bitmap_base(), 1L)
  assert_eq(acknack.num_bits(), 5U)
  assert_eq(acknack.bitmap(), [0x88000000U])
}

///|
test "reliable reader reassembles DATA_FRAG samples out of order" {
  let reader_id = @rtps.EntityId::new(b"rdr", 0xC7).unwrap()
  let writer_id = @rtps.EntityId::new(b"wrt", 0xC2).unwrap()
  let reader = ReliableDataReader::new(reader_id, writer_id)
  let final_fragment = @rtps.DataFragSubmessage::new(
    reader_id,
    writer_id,
    9L,
    3U,
    (1 : Int).to_uint16(),
    (4 : Int).to_uint16(),
    10U,
    b"ij",
  ).unwrap()
  let first_fragment = @rtps.DataFragSubmessage::new(
    reader_id,
    writer_id,
    9L,
    1U,
    (1 : Int).to_uint16(),
    (4 : Int).to_uint16(),
    10U,
    b"abcd",
  ).unwrap()
  let second_fragment = @rtps.DataFragSubmessage::new(
    reader_id,
    writer_id,
    9L,
    2U,
    (1 : Int).to_uint16(),
    (4 : Int).to_uint16(),
    10U,
    b"efgh",
  ).unwrap()
  assert_eq(reader.accept_data_frag(final_fragment), Ok(None))
  assert_eq(reader.accept_data_frag(first_fragment), Ok(None))
  let data = match reader.accept_data_frag(second_fragment) {
    Ok(Some(value)) => value
    Ok(None) => fail("the final DATA_FRAG did not complete the sample")
    Err(message) => fail(message)
  }
  assert_eq(data.writer_sequence_number(), 9L)
  assert_eq(data.serialized_payload(), b"abcdefghij")
  assert_eq(reader.sample_count(), 1)
}

///|
test "reliable reader requests missing DATA_FRAGs" {
  let reader_id = @rtps.EntityId::new(b"rdr", 0xC7).unwrap()
  let writer_id = @rtps.EntityId::new(b"wrt", 0xC2).unwrap()
  let reader = ReliableDataReader::new(reader_id, writer_id)
  let first_fragment = @rtps.DataFragSubmessage::new(
    reader_id,
    writer_id,
    10L,
    1U,
    (1 : Int).to_uint16(),
    (4 : Int).to_uint16(),
    10U,
    b"abcd",
  ).unwrap()
  assert_eq(reader.accept_data_frag(first_fragment), Ok(None))
  let heartbeat = @rtps.HeartbeatFragSubmessage::new(
    reader_id,
    writer_id,
    10L,
    3U,
    1U,
  ).unwrap()
  let nackfrag = reader.nackfrag_for_heartbeat_frag(heartbeat).unwrap()
  assert_eq(nackfrag.bitmap_base(), 1U)
  assert_eq(nackfrag.num_bits(), 3U)
  assert_eq(nackfrag.bitmap(), [0x60000000U])
  assert_eq(nackfrag.count(), 1U)
  assert_eq(reader.next_nackfrag_count(), 2U)
}

///|
test "reliable reader splits a large HEARTBEAT_FRAG into NACK_FRAG windows" {
  let reader_id = @rtps.EntityId::new(b"rdr", 0xC7).unwrap()
  let writer_id = @rtps.EntityId::new(b"wrt", 0xC2).unwrap()
  let reader = ReliableDataReader::new(reader_id, writer_id)
  let heartbeat = @rtps.HeartbeatFragSubmessage::new(
    reader_id,
    writer_id,
    10L,
    300U,
    1U,
  ).unwrap()
  let nackfrags = reader.nackfrags_for_heartbeat_frag(heartbeat).unwrap()
  assert_eq(nackfrags.length(), 2)
  assert_eq(nackfrags[0].bitmap_base(), 1U)
  assert_eq(nackfrags[0].num_bits(), 256U)
  assert_eq(nackfrags[0].count(), 1U)
  assert_eq(nackfrags[1].bitmap_base(), 257U)
  assert_eq(nackfrags[1].num_bits(), 44U)
  assert_eq(nackfrags[1].count(), 2U)
  assert_eq(reader.next_nackfrag_count(), 3U)
}
