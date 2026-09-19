///|
async test "reliable reader session receives discovered publication data" {
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let other_prefix = match
    @rtps.GuidPrefix::from_array([11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]) {
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
  let locator = match
    @rtps.Locator::udp_v4(
      b"\x7F\x00\x00\x01",
      sender.local_addr().port().reinterpret_as_uint(),
    ) {
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
  publication.add_unicast_locator(locator)
  let reader = match
    ReliableDataReaderSession::new_for_publication(
      receiver,
      prefix,
      @rtps.VendorId::new(1, 15),
      reader_id,
      publication,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let data = @rtps.DataSubmessage::new(reader_id, writer_id, 1L, b"payload")
  match
    sender.send_data(
      @rtps.DataSubmessage::new(reader_id, writer_id, 1L, b"other participant"),
      other_prefix,
      @rtps.VendorId::new(1, 15),
      receiver.local_addr(),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match
    sender.send_data(
      data,
      prefix,
      @rtps.VendorId::new(1, 15),
      receiver.local_addr(),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match
    sender.send_heartbeat(
      match @rtps.HeartbeatSubmessage::new(reader_id, writer_id, 1L, 1L, 99U) {
        Ok(value) => value
        Err(message) => fail(message)
      },
      other_prefix,
      @rtps.VendorId::new(1, 15),
      receiver.local_addr(),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match
    sender.send_heartbeat(
      match
        @rtps.HeartbeatSubmessage::new(
          @rtps.EntityId::unknown(),
          writer_id,
          1L,
          1L,
          1U,
        ) {
        Ok(value) => value
        Err(message) => fail(message)
      },
      prefix,
      @rtps.VendorId::new(1, 15),
      receiver.local_addr(),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (decoded, source) = match reader.receive_data() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (heartbeat, _) = match reader.receive_heartbeat() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (acknack, _) = match sender.receive_acknack() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.serialized_payload(), b"payload")
  assert_eq(heartbeat.last_sequence_number(), 1L)
  assert_eq(heartbeat.count(), 1U)
  assert_eq(acknack.num_bits(), 1U)
  assert_eq(acknack.bitmap(), [0U])
  assert_eq(reader.sample_count(), 1)
  assert_eq(source.ip(), 0x7F000001U)
  sender.close()
  reader.close()
}
