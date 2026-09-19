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
async test "reliable writer directs discovered endpoint traffic" {
  let local_prefix = @rtps.GuidPrefix::from_array(
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
  ).unwrap()
  let remote_prefix = @rtps.GuidPrefix::from_array(
    [11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
  ).unwrap()
  let reader_id = @rtps.EntityId::new(b"rdr", 0xC7).unwrap()
  let writer_id = @rtps.EntityId::new(b"wrt", 0xC2).unwrap()
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let locator = @rtps.Locator::udp_v4(
    b"\x7F\x00\x00\x01",
    receiver.local_addr().port().reinterpret_as_uint(),
  ).unwrap()
  let subscription = @rtps.SedpEndpointData::new(
    @rtps.SedpEndpointKind::Subscription,
    @rtps.Guid::new(remote_prefix, reader_id),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  subscription.add_unicast_locator(locator)
  let writer = ReliableDataWriter::new_for_subscription(
    sender,
    local_prefix,
    @rtps.VendorId::new(1, 15),
    writer_id,
    subscription,
    1L,
  ).unwrap()
  match writer.write(b"payload") {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (message, _) = receiver.receive_message().unwrap()
  assert_eq(message.destination_guid_prefix(), Ok(Some(remote_prefix)))
  let data = @rtps.DataSubmessage::from_submessage(
    message.submessages()[1],
  ).unwrap()
  assert_eq(data.serialized_payload(), b"payload")
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
  match
    ack_sender.send_heartbeat(
      match @rtps.HeartbeatSubmessage::new(reader_id, writer_id, 1L, 1L, 1U) {
        Ok(value) => value
        Err(message) => fail(message)
      },
      prefix,
      @rtps.VendorId::new(1, 15),
      writer_address,
    ) {
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

///|
async test "reliable writer fragments large samples and handles NACK_FRAG" {
  let prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let reader_id = @rtps.EntityId::new(b"rdr", 0xC7).unwrap()
  let writer_id = @rtps.EntityId::new(b"wrt", 0xC2).unwrap()
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let writer = ReliableDataWriter::new(
    sender,
    prefix,
    @rtps.VendorId::new(1, 15),
    reader_id,
    writer_id,
    receiver.local_addr(),
    1L,
  ).unwrap()
  let payload : Array[Byte] = []
  for index in 0..<(3010) {
    payload.push((index % 251).to_byte())
  }
  match writer.write(Bytes::from_array(payload)) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  assert_eq(writer.history_length(), 1)
  let (first_message, _) = receiver.receive_message().unwrap()
  let first_fragment = @rtps.DataFragSubmessage::from_submessage(
    first_message.submessages()[0],
  ).unwrap()
  let (second_message, _) = receiver.receive_message().unwrap()
  let second_fragment = @rtps.DataFragSubmessage::from_submessage(
    second_message.submessages()[0],
  ).unwrap()
  assert_eq(first_fragment.fragment_starting_number(), 1U)
  assert_eq(first_fragment.serialized_payload().length(), 1200)
  assert_eq(second_fragment.fragment_starting_number(), 2U)
  assert_eq(second_fragment.serialized_payload().length(), 1200)
  let (third_message, _) = receiver.receive_message().unwrap()
  let third_fragment = @rtps.DataFragSubmessage::from_submessage(
    third_message.submessages()[0],
  ).unwrap()
  assert_eq(third_fragment.fragment_starting_number(), 3U)
  assert_eq(third_fragment.serialized_payload().length(), 610)
  match writer.send_heartbeat() {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (heartbeat, _) = receiver.receive_heartbeat().unwrap()
  assert_eq(heartbeat.first_sequence_number(), 1L)
  let (heartbeat_frag_message, _) = receiver.receive_message().unwrap()
  let heartbeat_frag = @rtps.HeartbeatFragSubmessage::from_submessage(
    heartbeat_frag_message.submessages()[0],
  ).unwrap()
  assert_eq(heartbeat_frag.last_fragment_number(), 3U)
  let nackfrag = @rtps.NackFragSubmessage::new(
    reader_id,
    writer_id,
    1L,
    1U,
    3U,
    [0x40000000U],
    1U,
  ).unwrap()
  match
    receiver.send_nack_frag(
      nackfrag,
      prefix,
      @rtps.VendorId::new(1, 15),
      sender.local_addr(),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match writer.receive_control() {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (retransmitted_message, _) = receiver.receive_message().unwrap()
  let retransmitted = @rtps.DataFragSubmessage::from_submessage(
    retransmitted_message.submessages()[0],
  ).unwrap()
  assert_eq(retransmitted.fragment_starting_number(), 2U)
  assert_eq(retransmitted.serialized_payload().length(), 1200)
  writer.close()
  receiver.close()
}

///|
async test "reliable writer builds an SEDP builtin endpoint writer" {
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
  let endpoint_id = match @rtps.EntityId::new(b"ep1", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let endpoint = match
    @rtps.SedpEndpointData::new(
      @rtps.SedpEndpointKind::Publication,
      @rtps.Guid::new(prefix, endpoint_id),
      "rt/chatter",
      "std_msgs::msg::dds_::String_",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender_address = sender.local_addr()
  let locator = match
    @rtps.Locator::udp_v4(
      b"\x7F\x00\x00\x01",
      receiver.local_addr().port().reinterpret_as_uint(),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let remote_id = match @rtps.EntityId::new(b"rm1", 0xC1) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let remote = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(prefix, remote_id),
    @rtps.VendorId::new(1, 15),
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PUBLICATIONS_DETECTOR,
  )
  remote.add_metatraffic_unicast(locator)
  let writer = match
    ReliableSedpWriter::new(
      sender,
      @rtps.VendorId::new(1, 15),
      endpoint,
      remote,
      1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match writer.announce_once() {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (data, _) = match receiver.receive_data() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (heartbeat, _) = match receiver.receive_heartbeat() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(data.reader_id().key(), b"\x00\x00\x03")
  assert_eq(data.writer_id().key(), b"\x00\x00\x03")
  assert_eq(heartbeat.first_sequence_number(), 1L)
  let acknack = match
    @rtps.AckNackSubmessage::new(
      @rtps.SedpEndpointKind::Publication.builtin_reader_id(),
      @rtps.SedpEndpointKind::Publication.builtin_writer_id(),
      1L,
      1U,
      [0U],
      1U,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match
    receiver.send_acknack(
      match
        @rtps.AckNackSubmessage::new(
          @rtps.SedpEndpointKind::Publication.builtin_reader_id(),
          @rtps.SedpEndpointKind::Publication.builtin_writer_id(),
          1L,
          1U,
          [0U],
          99U,
        ) {
        Ok(value) => value
        Err(message) => fail(message)
      },
      other_prefix,
      @rtps.VendorId::new(1, 15),
      sender_address,
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match
    receiver.send_acknack(
      acknack,
      prefix,
      @rtps.VendorId::new(1, 15),
      sender_address,
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (decoded_acknack, _) = match writer.receive_acknack() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded_acknack.count(), 1U)
  assert_eq(writer.history_length(), 1)
  writer.close()
  receiver.close()
}
