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
  let reader = @wire.ReliableDataReader::new(reader_id, writer_id)
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
  assert_eq(acknack.bitmap_base(), 2L)
  assert_eq(acknack.num_bits(), 2U)
  assert_eq(acknack.bitmap(), [0xC0000000U])
  assert_eq(acknack.count(), 1U)
  assert_true(
    reader.accept_data(
      @rtps.DataSubmessage::new(reader_id, writer_id, 2L, b"second"),
    )
    is Ok(_),
  )
  assert_true(
    reader.accept_data(
      @rtps.DataSubmessage::new(reader_id, writer_id, 3L, b"third"),
    )
    is Ok(_),
  )
  let complete_acknack = reader.acknack_for_heartbeat(heartbeat).unwrap()
  assert_eq(complete_acknack.bitmap_base(), 4L)
  assert_eq(complete_acknack.num_bits(), 0U)
  assert_eq(complete_acknack.bitmap(), [])
  assert_eq(reader.samples.length(), 0)
  assert_eq(reader.sample_count(), 3)
}

///|
test "reliable reader limits ACKNACK to the first missing window" {
  let reader_id = @rtps.EntityId::new(b"rdr", 0xC7).unwrap()
  let writer_id = @rtps.EntityId::new(b"wrt", 0xC2).unwrap()
  let reader = @wire.ReliableDataReader::new(reader_id, writer_id)
  let heartbeat = @rtps.HeartbeatSubmessage::new(
    reader_id, writer_id, 1L, 300L, 1U,
  ).unwrap()
  let acknacks = reader.acknacks_for_heartbeat(heartbeat).unwrap()
  assert_eq(acknacks.length(), 1)
  assert_eq(acknacks[0].bitmap_base(), 1L)
  assert_eq(acknacks[0].num_bits(), 256U)
  assert_eq(acknacks[0].bitmap(), [
    0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU, 0xFFFFFFFFU,
    0xFFFFFFFFU, 0xFFFFFFFFU,
  ])
  assert_eq(acknacks[0].count(), 1U)
  for offset in 0..<256 {
    assert_true(
      reader.accept_data(
        @rtps.DataSubmessage::new(
          reader_id,
          writer_id,
          (offset + 1).to_int64(),
          b"received",
        ),
      )
      is Ok(_),
    )
  }
  let next_acknack = reader.acknacks_for_heartbeat(heartbeat).unwrap()[0]
  assert_eq(next_acknack.bitmap_base(), 257L)
  assert_eq(next_acknack.num_bits(), 44U)
  assert_eq(next_acknack.bitmap(), [0xFFFFFFFFU, 0xFFF00000U])
  assert_eq(next_acknack.count(), 2U)
  assert_eq(reader.next_acknack_count(), 3U)
  assert_eq(reader.samples.length(), 0)
  assert_eq(reader.sample_count(), 256)
}

///|
test "reliable reader accepts a multicast HEARTBEAT with unknown reader" {
  let reader_id = @rtps.EntityId::new(b"rdr", 0xC7).unwrap()
  let writer_id = @rtps.EntityId::new(b"wrt", 0xC2).unwrap()
  let reader = @wire.ReliableDataReader::new(reader_id, writer_id)
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
  let reader = @wire.ReliableDataReader::new(reader_id, writer_id)
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
  let reader = @wire.ReliableDataReader::new(reader_id, writer_id)
  let gap = @rtps.GapSubmessage::new(reader_id, writer_id, 2L, 4L, 5U, [
    0x90000000U,
  ]).unwrap()
  reader.accept_gap(gap).unwrap()
  let heartbeat = @rtps.HeartbeatSubmessage::new(
    reader_id, writer_id, 1L, 5L, 1U,
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
  let reader = @wire.ReliableDataReader::new(reader_id, writer_id)
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
  assert_eq(reader.fragments.length(), 0)
}

///|
test "reliable reader preserves KEY flag when reassembling DATA_FRAG" {
  let reader_id = @rtps.EntityId::new(b"rdr", 0xC7).unwrap()
  let writer_id = @rtps.EntityId::new(b"wrt", 0xC2).unwrap()
  let reader = @wire.ReliableDataReader::new(reader_id, writer_id)
  let first = @rtps.DataFragSubmessage::new(
    reader_id,
    writer_id,
    1L,
    1U,
    1U.to_uint16(),
    2U.to_uint16(),
    4U,
    b"ab",
  ).unwrap()
  let second = @rtps.DataFragSubmessage::new(
    reader_id,
    writer_id,
    1L,
    2U,
    1U.to_uint16(),
    2U.to_uint16(),
    4U,
    b"cd",
  ).unwrap()
  let first_key = @rtps.Submessage::new(
    DataFrag,
    (first.flags() & 0xFB) | @rtps.DATA_FLAG_KEY,
    first.to_payload(),
  )
  let second_key = @rtps.Submessage::new(
    DataFrag,
    (second.flags() & 0xFB) | @rtps.DATA_FLAG_KEY,
    second.to_payload(),
  )
  let decoded_first = @rtps.DataFragSubmessage::from_submessage(first_key).unwrap()
  let decoded_second = @rtps.DataFragSubmessage::from_submessage(second_key).unwrap()
  assert_eq(reader.accept_data_frag(decoded_first), Ok(None))
  let data = match reader.accept_data_frag(decoded_second) {
    Ok(Some(value)) => value
    Ok(None) => fail("the final key DATA_FRAG did not complete the sample")
    Err(message) => fail(message)
  }
  assert_true((data.flags() & @rtps.DATA_FLAG_KEY) != 0)
  assert_eq(data.serialized_payload(), b"abcd")
}

///|
test "reliable reader requests missing DATA_FRAGs" {
  let reader_id = @rtps.EntityId::new(b"rdr", 0xC7).unwrap()
  let writer_id = @rtps.EntityId::new(b"wrt", 0xC2).unwrap()
  let reader = @wire.ReliableDataReader::new(reader_id, writer_id)
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
    reader_id, writer_id, 10L, 3U, 1U,
  ).unwrap()
  let nackfrag = reader.nackfrag_for_heartbeat_frag(heartbeat).unwrap()
  assert_eq(nackfrag.bitmap_base(), 1U)
  assert_eq(nackfrag.num_bits(), 3U)
  assert_eq(nackfrag.bitmap(), [0x60000000U])
  assert_eq(nackfrag.count(), 1U)
  assert_eq(reader.next_nackfrag_count(), 2U)
  reader
  .accept_gap(
    @rtps.GapSubmessage::new(reader_id, writer_id, 10L, 11L, 0U, []).unwrap(),
  )
  .unwrap()
  let heartbeat = @rtps.HeartbeatSubmessage::new(
    reader_id, writer_id, 10L, 10L, 2U,
  ).unwrap()
  let acknack = reader.acknack_for_heartbeat(heartbeat).unwrap()
  assert_eq(acknack.bitmap_base(), 11L)
  assert_eq(acknack.num_bits(), 0U)
  assert_eq(reader.fragments.length(), 0)
  assert_eq(reader.gaps.length(), 0)
}

///|
test "reliable reader splits a large HEARTBEAT_FRAG into NACK_FRAG windows" {
  let reader_id = @rtps.EntityId::new(b"rdr", 0xC7).unwrap()
  let writer_id = @rtps.EntityId::new(b"wrt", 0xC2).unwrap()
  let reader = @wire.ReliableDataReader::new(reader_id, writer_id)
  let heartbeat = @rtps.HeartbeatFragSubmessage::new(
    reader_id, writer_id, 10L, 300U, 1U,
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
