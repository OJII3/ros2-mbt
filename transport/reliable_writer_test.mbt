///|
async test "reliable writer retransmits ACKNACK-selected samples" {
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let reader_id = match @rtps.EntityId::new(b"rdr", 0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match @rtps.EntityId::new(b"wrt", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let writer = match
    ReliableDataWriter::new(
      sender,
      prefix,
      @rtps.VendorId::new(1, 15),
      reader_id,
      writer_id,
      receiver.local_addr(),
      1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match writer.write(b"first") {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match writer.write(b"second") {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  assert_eq(writer.history_length(), 2)
  match writer.send_heartbeat() {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (first, _) = match receiver.receive_data() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (second, _) = match receiver.receive_data() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (heartbeat, _) = match receiver.receive_heartbeat() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(first.writer_sequence_number(), 1L)
  assert_eq(second.writer_sequence_number(), 2L)
  assert_eq(heartbeat.first_sequence_number(), 1L)
  assert_eq(heartbeat.last_sequence_number(), 2L)
  assert_eq(heartbeat.count(), 1U)
  let acknack = match
    @rtps.AckNackSubmessage::new(
      reader_id,
      writer_id,
      1L,
      2U,
      [0x40000000U],
      1U,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match writer.handle_acknack(acknack) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (retransmitted, _) = match receiver.receive_data() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(retransmitted.writer_sequence_number(), 2L)
  assert_eq(retransmitted.serialized_payload(), b"second")
  writer.close()
  receiver.close()
}

///|
async test "reliable writer receives ACKNACK from its socket" {
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let reader_id = match @rtps.EntityId::new(b"rdr", 0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match @rtps.EntityId::new(b"wrt", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let writer_address = writer_socket.local_addr()
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let ack_sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let writer = match
    ReliableDataWriter::new(
      writer_socket,
      prefix,
      @rtps.VendorId::new(1, 15),
      reader_id,
      writer_id,
      receiver.local_addr(),
      1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match writer.write(b"first") {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let acknack = match
    @rtps.AckNackSubmessage::new(
      reader_id,
      writer_id,
      1L,
      1U,
      [0x80000000U],
      1U,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match
    ack_sender.send_acknack(
      acknack,
      prefix,
      @rtps.VendorId::new(1, 15),
      writer_address,
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (decoded_acknack, _) = match writer.receive_acknack() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded_acknack.count(), 1U)
  let (retransmitted, _) = match receiver.receive_data() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(retransmitted.writer_sequence_number(), 1L)
  writer.close()
  ack_sender.close()
  receiver.close()
}
