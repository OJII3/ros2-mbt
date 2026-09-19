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
