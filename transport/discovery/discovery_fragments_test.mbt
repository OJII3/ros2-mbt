///|
async test "discovery session reassembles fragmented SPDP participant data" {
  let local_prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let remote_prefix = @rtps.GuidPrefix::from_array([
    11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
  ]).unwrap()
  let vendor_id = @rtps.VendorId::new(1, 15)
  let participant_id = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
  ).unwrap()
  let reader_id = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
  ).unwrap()
  let local_participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(local_prefix, participant_id),
    vendor_id,
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR,
  )
  let receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  defer receiver.close()
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  defer sender.close()
  let session = @discovery.DiscoverySession::new(
    receiver,
    local_participant,
    reader_id,
    participant_id,
    sender.local_addr(),
    1L,
  ).unwrap()
  let remote_participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(remote_prefix, participant_id),
    vendor_id,
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR,
  )
  let payload = remote_participant
    .to_data_submessage(reader_id, participant_id, 1L)
    .serialized_payload()
  let fragment_size = (payload.length() + 1) / 2
  let first_payload : Array[Byte] = []
  let final_payload : Array[Byte] = []
  for index in 0..<fragment_size {
    first_payload.push(payload[index])
  }
  for index in fragment_size..<payload.length() {
    final_payload.push(payload[index])
  }
  let message = @rtps.Message::new(@rtps.Header::new(remote_prefix, vendor_id))
  message.add(
    @rtps.DataFragSubmessage::new(
      reader_id,
      participant_id,
      1L,
      2U,
      1U.to_uint16(),
      fragment_size.to_uint16(),
      payload.length().reinterpret_as_uint(),
      Bytes::from_array(final_payload),
    )
    .unwrap()
    .to_submessage(),
  )
  message.add(
    @rtps.DataFragSubmessage::new(
      reader_id,
      participant_id,
      1L,
      1U,
      1U.to_uint16(),
      fragment_size.to_uint16(),
      payload.length().reinterpret_as_uint(),
      Bytes::from_array(first_payload),
    )
    .unwrap()
    .to_submessage(),
  )
  let marker = @rtps.SedpEndpointData::new(
    Publication,
    @rtps.Guid::new(
      remote_prefix,
      @rtps.EntityId::new(b"pub", @rtps.ENTITYID_SEDP_PUBLICATIONS_WRITER).unwrap(),
    ),
    "rt/marker",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  message.add(
    marker
    .to_data_submessage(
      @rtps.EntityId::unknown(),
      @rtps.SedpEndpointKind::Publication.builtin_writer_id(),
      1L,
    )
    .unwrap()
    .to_submessage(),
  )
  sender.send_message(message, session.socket.local_addr()).unwrap()
  match test_receive(() => session.receive_once()).unwrap().0 {
    Participant(discovered) =>
      assert_eq(
        discovered.participant_guid(),
        remote_participant.participant_guid(),
      )
    _ => fail("expected the reassembled SPDP participant")
  }
  match test_receive(() => session.receive_once()).unwrap().0 {
    Publication(publication) => assert_eq(publication.topic_name(), "rt/marker")
    _ => fail("expected the coalesced SEDP publication")
  }
  let dispose = remote_participant.to_dispose_data_submessage(
    reader_id, participant_id, 2L,
  )
  let key_payload = dispose.serialized_payload()
  let first_key_payload : Array[Byte] = []
  let final_key_payload : Array[Byte] = []
  for index in 0..<8 {
    first_key_payload.push(key_payload[index])
    final_key_payload.push(key_payload[index + 8])
  }
  let final_key_fragment = @rtps.DataFragSubmessage::new(
    reader_id,
    participant_id,
    2L,
    2U,
    1U.to_uint16(),
    8U.to_uint16(),
    key_payload.length().reinterpret_as_uint(),
    Bytes::from_array(final_key_payload),
  ).unwrap()
  let first_key_fragment = @rtps.DataFragSubmessage::new(
      reader_id,
      participant_id,
      2L,
      1U,
      1U.to_uint16(),
      8U.to_uint16(),
      key_payload.length().reinterpret_as_uint(),
      Bytes::from_array(first_key_payload),
    )
    .unwrap()
    .with_inline_qos(dispose.inline_qos())
  let fragmented_dispose = @rtps.Message::new(
    @rtps.Header::new(remote_prefix, vendor_id),
  )
  fragmented_dispose.add(
    @rtps.Submessage::new(
      DataFrag,
      (final_key_fragment.flags() & 0xFB) | @rtps.DATA_FLAG_KEY,
      final_key_fragment.to_payload(),
    ),
  )
  fragmented_dispose.add(
    @rtps.Submessage::new(
      DataFrag,
      (first_key_fragment.flags() & 0xFB) | @rtps.DATA_FLAG_KEY,
      first_key_fragment.to_payload(),
    ),
  )
  sender.send_message(fragmented_dispose, session.socket.local_addr()).unwrap()
  match test_receive(() => session.receive_once()).unwrap().0 {
    ParticipantRemoved(participant_guid) =>
      assert_eq(participant_guid, remote_participant.participant_guid())
    _ => fail("expected the reassembled SPDP participant removal")
  }
  session.close()
  sender.close()
}

///|
async test "discovery session filters SEDP data for another builtin reader" {
  let local_prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let remote_prefix = @rtps.GuidPrefix::from_array([
    11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
  ]).unwrap()
  let spdp_reader = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
  ).unwrap()
  let spdp_writer = @rtps.EntityId::new(
    b"\x00\x01\x00",
    @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
  ).unwrap()
  let participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(local_prefix, spdp_writer),
    @rtps.VendorId::new(1, 15),
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER,
  )
  let receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  defer receiver.close()
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  defer sender.close()
  let session = @discovery.DiscoverySession::new(
    receiver,
    participant,
    spdp_reader,
    spdp_writer,
    sender.local_addr(),
    1L,
  ).unwrap()
  let endpoint = @rtps.SedpEndpointData::new(
    Publication,
    @rtps.Guid::new(remote_prefix, @rtps.EntityId::new(b"pub", 0xC2).unwrap()),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  let wrong_reader = @rtps.EntityId::new(b"bad", 0xC7).unwrap()
  sender
  .send_data(
    endpoint
    .to_data_submessage(
      wrong_reader,
      @rtps.SedpEndpointKind::Publication.builtin_writer_id(),
      1L,
    )
    .unwrap(),
    remote_prefix,
    @rtps.VendorId::new(1, 15),
    session.socket.local_addr(),
  )
  .unwrap()
  sender
  .send_data(
    endpoint
    .to_data_submessage(
      @rtps.SedpEndpointKind::Publication.builtin_reader_id(),
      @rtps.SedpEndpointKind::Publication.builtin_writer_id(),
      2L,
    )
    .unwrap(),
    remote_prefix,
    @rtps.VendorId::new(1, 15),
    session.socket.local_addr(),
  )
  .unwrap()
  let (event, _) = test_receive(() => session.receive_once()).unwrap()
  match event {
    Publication(publication) =>
      assert_eq(publication.endpoint_guid(), endpoint.endpoint_guid())
    Participant(_) => fail("expected an SEDP publication")
    Subscription(_) => fail("expected an SEDP publication")
    EndpointRemoved(_, _) => fail("expected an SEDP publication")
    ParticipantRemoved(_) => fail("expected an SEDP publication")
  }
  session.close()
  sender.close()
}
