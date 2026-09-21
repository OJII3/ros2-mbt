///|
fn transport_reliability_ids() -> Result[
  (@rtps.EntityId, @rtps.EntityId),
  String,
] {
  let reader_id = match @rtps.EntityId::new(b"rdr", 0xC7) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let writer_id = match @rtps.EntityId::new(b"wrt", 0xC2) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok((reader_id, writer_id))
}

///|
async test "UDP sends and receives HEARTBEAT and ACKNACK" {
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (reader_id, writer_id) = match transport_reliability_ids() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let heartbeat = match
    @rtps.HeartbeatSubmessage::new(reader_id, writer_id, 1L, 2L, 1U) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let acknack = match
    @rtps.AckNackSubmessage::new(
      reader_id,
      writer_id,
      1L,
      2U,
      [0x00000002U],
      1U,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  match
    sender.send_heartbeat(
      heartbeat,
      prefix,
      @rtps.VendorId::new(1, 15),
      receiver.local_addr(),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match
    sender.send_acknack(
      acknack,
      prefix,
      @rtps.VendorId::new(1, 15),
      receiver.local_addr(),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (received_heartbeat, source) = match receiver.receive_heartbeat() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (received_acknack, _) = match receiver.receive_acknack() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(received_heartbeat.last_sequence_number(), 2L)
  assert_eq(received_acknack.bitmap(), [0x00000002U])
  assert_eq(source.ip(), 0x7F000001U)
  sender.close()
  receiver.close()
}
