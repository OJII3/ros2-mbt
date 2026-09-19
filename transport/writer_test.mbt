///|
async test "best-effort data writer increments sequence numbers" {
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
    DataWriter::new(
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
  assert_eq(writer.next_sequence_number(), 3L)
  let (first, _) = match receiver.receive_data() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (second, _) = match receiver.receive_data() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(first.writer_sequence_number(), 1L)
  assert_eq(first.serialized_payload(), b"first")
  assert_eq(second.writer_sequence_number(), 2L)
  assert_eq(second.serialized_payload(), b"second")
  writer.close()
  receiver.close()
}
