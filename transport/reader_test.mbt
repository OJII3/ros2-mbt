///|
async test "best-effort reader accepts its discovered publication" {
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
  let publication = match
    @rtps.SedpEndpointData::new(
      @rtps.SedpEndpointKind::Publication,
      @rtps.Guid::new(prefix, writer_id),
      "rt/chatter",
      "std_msgs::msg::dds_::String_",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let reader = match
    DataReader::new_for_publication(receiver, reader_id, publication) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let data = @rtps.DataSubmessage::new(reader_id, writer_id, 1L, b"payload")
  match
    sender.send_data(
      data,
      prefix,
      @rtps.VendorId::new(1, 15),
      @socket.Addr::new(0x7F000001U, reader.socket.local_addr().port()),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (decoded, source) = match reader.receive() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.serialized_payload(), b"payload")
  assert_eq(source.ip(), 0x7F000001U)
  sender.close()
  reader.close()
}
