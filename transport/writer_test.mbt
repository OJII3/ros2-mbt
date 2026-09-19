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

///|
async test "best-effort data writer fragments large samples" {
  let prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let reader_id = @rtps.EntityId::new(b"rdr", 0xC7).unwrap()
  let writer_id = @rtps.EntityId::new(b"wrt", 0xC2).unwrap()
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let writer = DataWriter::new(
    sender,
    prefix,
    @rtps.VendorId::new(1, 15),
    reader_id,
    writer_id,
    receiver.local_addr(),
    1L,
  ).unwrap()
  let reader = DataReader::new(receiver, reader_id, writer_id)
  let payload : Array[Byte] = []
  for index in 0..<(3010) {
    payload.push((index % 251).to_byte())
  }
  let expected = Bytes::from_array(payload)
  writer.write(expected).unwrap()
  assert_eq(writer.next_sequence_number(), 2L)
  let (decoded, source) = reader.receive().unwrap()
  assert_eq(decoded.writer_sequence_number(), 1L)
  assert_eq(decoded.serialized_payload(), expected)
  assert_eq(source.ip(), 0x7F000001U)
  writer.close()
  reader.close()
}
