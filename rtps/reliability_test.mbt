///|
fn reliability_test_ids() -> Result[(EntityId, EntityId), String] {
  let reader_id = match EntityId::new(b"rdr", 0xC7) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let writer_id = match EntityId::new(b"wrt", 0xC2) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok((reader_id, writer_id))
}

///|
test "RTPS HEARTBEAT round trip" {
  let (reader_id, writer_id) = match reliability_test_ids() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let heartbeat = match
    HeartbeatSubmessage::new(reader_id, writer_id, 1L, 3L, 7U) {
    Ok(value) => value.with_final()
    Err(message) => fail(message)
  }
  let encoded = match heartbeat.to_submessage().to_bytes() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(encoded[0], 0x07)
  assert_eq(encoded[1], HEARTBEAT_FLAG_LITTLE_ENDIAN | HEARTBEAT_FLAG_FINAL)
  let submessage = match Submessage::from_bytes(encoded) {
    Ok((value, _)) => value
    Err(message) => fail(message)
  }
  let decoded = match HeartbeatSubmessage::from_submessage(submessage) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.first_sequence_number(), 1L)
  assert_eq(decoded.last_sequence_number(), 3L)
  assert_eq(decoded.count(), 7U)
  assert_eq(decoded.flags(), heartbeat.flags())
}

///|
test "RTPS ACKNACK round trips a partial bitmap" {
  let (reader_id, writer_id) = match reliability_test_ids() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let acknack = match
    AckNackSubmessage::new(
      reader_id,
      writer_id,
      5L,
      33U,
      [0x80000001U, 0x00000001U],
      4U,
    ) {
    Ok(value) => value.with_final()
    Err(message) => fail(message)
  }
  let submessage = match
    Submessage::from_bytes(
      match acknack.to_submessage().to_bytes() {
        Ok(value) => value
        Err(message) => fail(message)
      },
    ) {
    Ok((value, _)) => value
    Err(message) => fail(message)
  }
  let decoded = match AckNackSubmessage::from_submessage(submessage) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.bitmap_base(), 5L)
  assert_eq(decoded.num_bits(), 33U)
  assert_eq(decoded.bitmap(), [0x80000001U, 0x00000001U])
  assert_eq(decoded.count(), 4U)
  assert_eq(decoded.flags(), acknack.flags())
}

///|
test "RTPS GAP round trips range and bitmap gaps" {
  let (reader_id, writer_id) = match reliability_test_ids() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let gap = match
    GapSubmessage::new(reader_id, writer_id, 2L, 4L, 5U, [0x90000000U]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let submessage = match
    Submessage::from_bytes(
      match gap.to_submessage().to_bytes() {
        Ok(value) => value
        Err(message) => fail(message)
      },
    ) {
    Ok((value, _)) => value
    Err(message) => fail(message)
  }
  let decoded = match GapSubmessage::from_submessage(submessage) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.gap_start(), 2L)
  assert_eq(decoded.gap_list_base(), 4L)
  assert_eq(decoded.gap_list_num_bits(), 5U)
  assert_eq(decoded.gap_list_bitmap(), [0x90000000U])
  assert_true(decoded.contains_sequence(2L))
  assert_true(decoded.contains_sequence(3L))
  assert_true(decoded.contains_sequence(4L))
  assert_true(decoded.contains_sequence(7L))
  assert_false(decoded.contains_sequence(1L))
  assert_false(decoded.contains_sequence(5L))
  assert_false(decoded.contains_sequence(8L))
  assert_eq(decoded.flags(), gap.flags())
}

///|
test "RTPS reliability codecs reject invalid ranges" {
  let (reader_id, writer_id) = match reliability_test_ids() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_true(
    HeartbeatSubmessage::new(reader_id, writer_id, 3L, 2L, 1U) is Err(_),
  )
  assert_true(
    AckNackSubmessage::new(reader_id, writer_id, 1L, 33U, [0U], 1U) is Err(_),
  )
  assert_true(
    AckNackSubmessage::new(reader_id, writer_id, 1L, 257U, [], 1U) is Err(_),
  )
  assert_true(
    GapSubmessage::new(reader_id, writer_id, 3L, 2L, 0U, []) is Err(_),
  )
  assert_true(
    GapSubmessage::new(reader_id, writer_id, 1L, 1L, 33U, []) is Err(_),
  )
}

///|
test "RTPS fragment reliability codecs round trip" {
  let (reader_id, writer_id) = reliability_test_ids().unwrap()
  let heartbeat = HeartbeatFragSubmessage::new(
    reader_id,
    writer_id,
    9L,
    7U,
    3U,
  ).unwrap()
  let heartbeat_submessage = Submessage::from_bytes(
    heartbeat.to_submessage().to_bytes().unwrap(),
  ).unwrap().0
  let decoded_heartbeat = HeartbeatFragSubmessage::from_submessage(
    heartbeat_submessage,
  ).unwrap()
  assert_eq(decoded_heartbeat.writer_sequence_number(), 9L)
  assert_eq(decoded_heartbeat.last_fragment_number(), 7U)
  assert_eq(decoded_heartbeat.count(), 3U)

  let nack = NackFragSubmessage::new(
    reader_id,
    writer_id,
    9L,
    1U,
    7U,
    [0xA0000000U],
    4U,
  ).unwrap()
  let nack_submessage = Submessage::from_bytes(
    nack.to_submessage().to_bytes().unwrap(),
  ).unwrap().0
  let decoded_nack = NackFragSubmessage::from_submessage(nack_submessage).unwrap()
  assert_eq(decoded_nack.writer_sequence_number(), 9L)
  assert_eq(decoded_nack.bitmap_base(), 1U)
  assert_eq(decoded_nack.num_bits(), 7U)
  assert_eq(decoded_nack.bitmap(), [0xA0000000U])
  assert_eq(decoded_nack.count(), 4U)
}
