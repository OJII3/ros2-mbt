///|
async test "best-effort reader accepts its discovered publication" {
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
  let publication = match
    @rtps.SedpEndpointData::new(
      Publication,
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
    DataReader::new_for_publication_with_prefix(
      receiver, prefix, reader_id, publication,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let data = @rtps.DataSubmessage::new(reader_id, writer_id, 1L, b"payload")
  match
    sender.send_heartbeat(
      match @rtps.HeartbeatSubmessage::new(reader_id, writer_id, 1L, 1L, 1U) {
        Ok(value) => value
        Err(message) => fail(message)
      },
      prefix,
      @rtps.VendorId::new(1, 15),
      @socket.Addr::new(0x7F000001U, reader.socket.local_addr().port()),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match
    sender.send_data(
      @rtps.DataSubmessage::new(
        reader_id,
        match @rtps.EntityId::new(b"oth", 0xC2) {
          Ok(value) => value
          Err(message) => fail(message)
        },
        1L,
        b"unrelated",
      ),
      prefix,
      @rtps.VendorId::new(1, 15),
      @socket.Addr::new(0x7F000001U, reader.socket.local_addr().port()),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match
    sender.send_data(
      @rtps.DataSubmessage::new(reader_id, writer_id, 1L, b"other participant"),
      other_prefix,
      @rtps.VendorId::new(1, 15),
      @socket.Addr::new(0x7F000001U, reader.socket.local_addr().port()),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let wrong_destination = @rtps.Message::new(
    @rtps.Header::new(prefix, @rtps.VendorId::new(1, 15)),
  )
  wrong_destination.add(
    @rtps.InfoDestinationSubmessage::new(other_prefix).to_submessage(),
  )
  wrong_destination.add(
    @rtps.DataSubmessage::new(reader_id, writer_id, 1L, b"wrong destination").to_submessage(),
  )
  match
    sender.send_message(
      wrong_destination,
      @socket.Addr::new(0x7F000001U, reader.socket.local_addr().port()),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
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

///|
async test "best-effort reader accepts DATA with an unknown reader ID" {
  let prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let reader_id = @rtps.EntityId::new(b"rdr", 0xC7).unwrap()
  let writer_id = @rtps.EntityId::new(b"wrt", 0xC2).unwrap()
  let publication = @rtps.SedpEndpointData::new(
    Publication,
    @rtps.Guid::new(prefix, writer_id),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let reader = DataReader::new_for_publication(receiver, reader_id, publication).unwrap()
  sender
  .send_data(
    @rtps.DataSubmessage::new(
      @rtps.EntityId::unknown(),
      writer_id,
      1L,
      b"multicast payload",
    ),
    prefix,
    @rtps.VendorId::new(1, 15),
    reader.socket.local_addr(),
  )
  .unwrap()
  let (decoded, _) = reader.receive().unwrap()
  assert_eq(decoded.serialized_payload(), b"multicast payload")
  sender.close()
  reader.close()
}

///|
async test "best-effort reader reassembles DATA_FRAG over UDP" {
  let prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let reader_id = @rtps.EntityId::new(b"rdr", 0xC7).unwrap()
  let writer_id = @rtps.EntityId::new(b"wrt", 0xC2).unwrap()
  let publication = @rtps.SedpEndpointData::new(
    Publication,
    @rtps.Guid::new(prefix, writer_id),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let reader = DataReader::new_for_publication(receiver, reader_id, publication).unwrap()
  let fragments = [
    @rtps.DataFragSubmessage::new(
      reader_id,
      writer_id,
      2L,
      3U,
      (1 : Int).to_uint16(),
      (4 : Int).to_uint16(),
      10U,
      b"ij",
    ).unwrap(),
    @rtps.DataFragSubmessage::new(
      reader_id,
      writer_id,
      2L,
      1U,
      (1 : Int).to_uint16(),
      (4 : Int).to_uint16(),
      10U,
      b"abcd",
    ).unwrap(),
    @rtps.DataFragSubmessage::new(
      reader_id,
      writer_id,
      2L,
      2U,
      (1 : Int).to_uint16(),
      (4 : Int).to_uint16(),
      10U,
      b"efgh",
    ).unwrap(),
  ]
  for fragment in fragments {
    match
      sender.send_message(
        fragment.to_message(prefix, @rtps.VendorId::new(1, 15)),
        reader.socket.local_addr(),
      ) {
      Ok(_) => ()
      Err(message) => fail(message)
    }
  }
  let (data, _) = reader.receive().unwrap()
  assert_eq(data.writer_sequence_number(), 2L)
  assert_eq(data.serialized_payload(), b"abcdefghij")
  sender.close()
  reader.close()
}
