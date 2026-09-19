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

///|
async test "reliable reader session applies GAP before acknowledging HEARTBEAT" {
  let prefix = @rtps.GuidPrefix::from_array(
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
  ).unwrap()
  let reader_id = @rtps.EntityId::new(b"rdr", 0xC7).unwrap()
  let writer_id = @rtps.EntityId::new(b"wrt", 0xC2).unwrap()
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let locator = @rtps.Locator::udp_v4(
    b"\x7F\x00\x00\x01",
    sender.local_addr().port().reinterpret_as_uint(),
  ).unwrap()
  let publication = @rtps.SedpEndpointData::new(
    @rtps.SedpEndpointKind::Publication,
    @rtps.Guid::new(prefix, writer_id),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  publication.add_unicast_locator(locator)
  let reader = ReliableDataReaderSession::new_for_publication(
    receiver,
    prefix,
    @rtps.VendorId::new(1, 15),
    reader_id,
    publication,
  ).unwrap()
  let gap = @rtps.GapSubmessage::new(
    reader_id,
    writer_id,
    2L,
    4L,
    5U,
    [0x90000000U],
  ).unwrap()
  match
    sender.send_message(
      gap.to_message(prefix, @rtps.VendorId::new(1, 15)),
      receiver.local_addr(),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let heartbeat = @rtps.HeartbeatSubmessage::new(
    reader_id,
    writer_id,
    1L,
    5L,
    1U,
  ).unwrap()
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
  let (received, _) = reader.receive_heartbeat().unwrap()
  let (acknack, _) = sender.receive_acknack().unwrap()
  assert_eq(received.last_sequence_number(), 5L)
  assert_eq(acknack.bitmap_base(), 1L)
  assert_eq(acknack.num_bits(), 5U)
  assert_eq(acknack.bitmap(), [0x88000000U])
  sender.close()
  reader.close()
}

///|
async test "reliable reader session sends ACKNACK windows for a large HEARTBEAT" {
  let prefix = @rtps.GuidPrefix::from_array(
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
  ).unwrap()
  let reader_id = @rtps.EntityId::new(b"rdr", 0xC7).unwrap()
  let writer_id = @rtps.EntityId::new(b"wrt", 0xC2).unwrap()
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let locator = @rtps.Locator::udp_v4(
    b"\x7F\x00\x00\x01",
    sender.local_addr().port().reinterpret_as_uint(),
  ).unwrap()
  let publication = @rtps.SedpEndpointData::new(
    @rtps.SedpEndpointKind::Publication,
    @rtps.Guid::new(prefix, writer_id),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  publication.add_unicast_locator(locator)
  let reader = ReliableDataReaderSession::new_for_publication(
    receiver,
    prefix,
    @rtps.VendorId::new(1, 15),
    reader_id,
    publication,
  ).unwrap()
  let heartbeat = @rtps.HeartbeatSubmessage::new(
    reader_id,
    writer_id,
    1L,
    300L,
    1U,
  ).unwrap()
  sender
  .send_heartbeat(
    heartbeat,
    prefix,
    @rtps.VendorId::new(1, 15),
    receiver.local_addr(),
  )
  .unwrap()
  let (received, _) = reader.receive_heartbeat().unwrap()
  let (first, _) = sender.receive_acknack().unwrap()
  let (second, _) = sender.receive_acknack().unwrap()
  assert_eq(received.last_sequence_number(), 300L)
  assert_eq(first.bitmap_base(), 1L)
  assert_eq(first.num_bits(), 256U)
  assert_eq(second.bitmap_base(), 257L)
  assert_eq(second.num_bits(), 44U)
  reader.close()
  sender.close()
}

///|
async test "reliable reader session sends NACK_FRAG windows for a large sample" {
  let prefix = @rtps.GuidPrefix::from_array(
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
  ).unwrap()
  let reader_id = @rtps.EntityId::new(b"rdr", 0xC7).unwrap()
  let writer_id = @rtps.EntityId::new(b"wrt", 0xC2).unwrap()
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let locator = @rtps.Locator::udp_v4(
    b"\x7F\x00\x00\x01",
    sender.local_addr().port().reinterpret_as_uint(),
  ).unwrap()
  let publication = @rtps.SedpEndpointData::new(
    @rtps.SedpEndpointKind::Publication,
    @rtps.Guid::new(prefix, writer_id),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  publication.add_unicast_locator(locator)
  let reader = ReliableDataReaderSession::new_for_publication(
    receiver,
    prefix,
    @rtps.VendorId::new(1, 15),
    reader_id,
    publication,
  ).unwrap()
  sender
  .send_heartbeat_frag(
    @rtps.HeartbeatFragSubmessage::new(
      reader_id,
      writer_id,
      10L,
      300U,
      1U,
    ).unwrap(),
    prefix,
    @rtps.VendorId::new(1, 15),
    receiver.local_addr(),
  )
  .unwrap()
  sender
  .send_heartbeat(
    @rtps.HeartbeatSubmessage::new(reader_id, writer_id, 1L, 1L, 1U).unwrap(),
    prefix,
    @rtps.VendorId::new(1, 15),
    receiver.local_addr(),
  )
  .unwrap()
  let (_, _) = reader.receive_heartbeat().unwrap()
  let (first, _) = sender.receive_nack_frag().unwrap()
  let (second, _) = sender.receive_nack_frag().unwrap()
  let (_, _) = sender.receive_acknack().unwrap()
  assert_eq(first.bitmap_base(), 1U)
  assert_eq(first.num_bits(), 256U)
  assert_eq(second.bitmap_base(), 257U)
  assert_eq(second.num_bits(), 44U)
  reader.close()
  sender.close()
}

///|
async test "reliable reader session reassembles DATA_FRAG over UDP" {
  let prefix = @rtps.GuidPrefix::from_array(
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
  ).unwrap()
  let reader_id = @rtps.EntityId::new(b"rdr", 0xC7).unwrap()
  let writer_id = @rtps.EntityId::new(b"wrt", 0xC2).unwrap()
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let locator = @rtps.Locator::udp_v4(
    b"\x7F\x00\x00\x01",
    sender.local_addr().port().reinterpret_as_uint(),
  ).unwrap()
  let publication = @rtps.SedpEndpointData::new(
    @rtps.SedpEndpointKind::Publication,
    @rtps.Guid::new(prefix, writer_id),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  publication.add_unicast_locator(locator)
  let reader = ReliableDataReaderSession::new_for_publication(
    receiver,
    prefix,
    @rtps.VendorId::new(1, 15),
    reader_id,
    publication,
  ).unwrap()
  let first_fragment = @rtps.DataFragSubmessage::new(
      reader_id,
      writer_id,
      4L,
      1U,
      (1 : Int).to_uint16(),
      (4 : Int).to_uint16(),
      10U,
      b"abcd",
    ).unwrap()
  match
    sender.send_message(
      first_fragment.to_message(prefix, @rtps.VendorId::new(1, 15)),
      receiver.local_addr(),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let heartbeat = @rtps.HeartbeatFragSubmessage::new(
    reader_id,
    writer_id,
    4L,
    3U,
    1U,
  ).unwrap()
  match
    sender.send_heartbeat_frag(
      heartbeat,
      prefix,
      @rtps.VendorId::new(1, 15),
      receiver.local_addr(),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let remaining_fragments = [
    @rtps.DataFragSubmessage::new(
      reader_id,
      writer_id,
      4L,
      3U,
      (1 : Int).to_uint16(),
      (4 : Int).to_uint16(),
      10U,
      b"ij",
    ).unwrap(),
    @rtps.DataFragSubmessage::new(
      reader_id,
      writer_id,
      4L,
      2U,
      (1 : Int).to_uint16(),
      (4 : Int).to_uint16(),
      10U,
      b"efgh",
    ).unwrap(),
  ]
  for fragment in remaining_fragments {
    match
      sender.send_message(
        fragment.to_message(prefix, @rtps.VendorId::new(1, 15)),
        receiver.local_addr(),
      ) {
      Ok(_) => ()
      Err(message) => fail(message)
    }
  }
  let (data, identity, _) = reader.receive_data_with_identity().unwrap()
  assert_eq(data.writer_sequence_number(), 4L)
  assert_eq(data.serialized_payload(), b"abcdefghij")
  assert_eq(identity.sequence_number(), 4L)
  let (nackfrag, _) = sender.receive_nack_frag().unwrap()
  assert_eq(nackfrag.writer_sequence_number(), 4L)
  assert_eq(nackfrag.bitmap_base(), 1U)
  assert_eq(nackfrag.num_bits(), 3U)
  assert_eq(nackfrag.bitmap(), [0x60000000U])
  sender.close()
  reader.close()
}
