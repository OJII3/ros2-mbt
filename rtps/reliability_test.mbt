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
}
