///|
fn sender_test_new() -> @discovery.DiscoverySender {
  @discovery.DiscoverySender::new(
    state_test_participant(0, 60, 0U),
    @core.EntityId::new(
      b"\x00\x01\x00",
      @discovery.ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
    ).unwrap(),
    @core.EntityId::new(
      b"\x00\x01\x00",
      @discovery.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
    ).unwrap(),
    @core.Locator::udp_v4(b"\xEF\xFF\x00\x01", 7400).unwrap(),
    17L,
  ).unwrap()
}

///|
fn sender_test_endpoint(large : Bool) -> @discovery.SedpEndpointData {
  let participant = state_test_participant(0, 60, 0U)
  let endpoint = @discovery.SedpEndpointData::new(
      Publication,
      @core.Guid::new(
        participant.participant_guid().prefix(),
        @core.EntityId::new(b"abc", 0x02).unwrap(),
      ),
      "rt/chatter",
      "std_msgs::msg::dds_::String_",
    )
    .unwrap()
    .with_participant_guid(participant.participant_guid())
  if large {
    endpoint.add_parameter(
      @discovery.qos_user_data(Bytes::from_array(Array::make(4000, 0x41))),
    )
  }
  endpoint
}

///|
fn sender_test_remote() -> @discovery.SpdpParticipantData {
  let remote = state_test_participant(1, 60, 0U)
  remote.add_metatraffic_unicast(
    @core.Locator::udp_v4(b"\x7F\x00\x00\x01", 7410).unwrap(),
  )
  remote
}

///|
test "discovery sender consumes SPDP sequences when producing effects" {
  let sender = sender_test_new()
  let first = sender.announce_spdp(false).unwrap()
  let second = sender.announce_spdp(true).unwrap()
  assert_eq(sender.next_sequence_number(), 19L)
  assert_eq(first.length(), 1)
  let data = @core.DataSubmessage::from_submessage(
    first[0].message.submessages()[0],
  ).unwrap()
  assert_eq(data.writer_sequence_number(), 17L)
  let disposed = @core.DataSubmessage::from_submessage(
    second[0].message.submessages()[0],
  ).unwrap()
  assert_eq(disposed.writer_sequence_number(), 18L)
  assert_eq(
    disposed.status_info().unwrap(),
    Some(@core.STATUS_INFO_DISPOSED | @core.STATUS_INFO_UNREGISTERED),
  )
}

///|
test "discovery writer sequences are per kind and history survives acknowledgements" {
  let sender = sender_test_new()
  let remote = sender_test_remote()
  let kind = @discovery.SedpEndpointKind::Publication
  let first = sender
    .announce_sedp(sender_test_endpoint(false), [remote], false)
    .unwrap()
  assert_eq(first.length(), 2)
  assert_eq(first[0].destination, remote.metatraffic_unicast_locators()[0])
  assert_eq(
    first[0].message.destination_guid_prefix().unwrap(),
    Some(remote.participant_guid().prefix()),
  )
  assert_eq(sender.next_sedp_sequence_number(Publication), 2L)
  assert_eq(sender.next_sedp_sequence_number(Subscription), 1L)
  let source = remote.metatraffic_unicast_locators()[0]
  let ack = @core.AckNackSubmessage::new(
    kind.builtin_reader_id(),
    kind.builtin_writer_id(),
    2L,
    0U,
    [],
    1U,
  ).unwrap()
  assert_eq(
    sender
    .retransmit_acknack(remote.participant_guid().prefix(), ack, source)
    .unwrap()
    .length(),
    0,
  )
  let request = @core.AckNackSubmessage::new(
    kind.builtin_reader_id(),
    kind.builtin_writer_id(),
    1L,
    1U,
    [0x80000000U],
    2U,
  ).unwrap()
  let resend = sender
    .retransmit_acknack(remote.participant_guid().prefix(), request, source)
    .unwrap()
  assert_eq(resend.length(), 1)
  assert_eq(
    @core.DataSubmessage::from_submessage(resend[0].message.submessages()[1])
    .unwrap()
    .writer_sequence_number(),
    1L,
  )
  assert_eq(
    sender
    .retransmit_acknack(remote.participant_guid().prefix(), request, source)
    .unwrap()
    .length(),
    0,
  )
  sender.forget_remote_participant(remote.participant_guid().prefix())
  assert_eq(
    sender
    .retransmit_acknack(remote.participant_guid().prefix(), request, source)
    .unwrap()
    .length(),
    1,
  )
}

///|
test "discovery sender fragments and retransmits selected fragments with count rollover" {
  let sender = sender_test_new()
  let remote = sender_test_remote()
  let output = sender
    .announce_sedp(sender_test_endpoint(true), [remote], false)
    .unwrap()
  let mut fragments = 0
  let mut fragment_heartbeat = false
  for effect in output {
    for submessage in effect.message.submessages() {
      if submessage.id() == DataFrag {
        fragments += 1
      }
      if submessage.id() == HeartbeatFrag {
        fragment_heartbeat = true
      }
    }
  }
  assert_true(fragments >= 4)
  assert_true(fragment_heartbeat)
  let kind = @discovery.SedpEndpointKind::Publication
  let nack = @core.NackFragSubmessage::new(
    kind.builtin_reader_id(),
    kind.builtin_writer_id(),
    1L,
    2U,
    2U,
    [0xC0000000U],
    0xFFFFFFFFU,
  ).unwrap()
  let source = remote.metatraffic_unicast_locators()[0]
  let prefix = remote.participant_guid().prefix()
  let resend = sender.retransmit_nackfrag(prefix, nack, source).unwrap()
  assert_eq(resend.length(), 2)
  let second = @core.DataFragSubmessage::from_submessage(
    resend[0].message.submessages()[1],
  ).unwrap()
  let third = @core.DataFragSubmessage::from_submessage(
    resend[1].message.submessages()[1],
  ).unwrap()
  assert_eq(second.fragment_starting_number(), 2U)
  assert_eq(third.fragment_starting_number(), 3U)
  assert_eq(
    sender.retransmit_nackfrag(prefix, nack, source).unwrap().length(),
    0,
  )
  let wrapped = @core.NackFragSubmessage::new(
    kind.builtin_reader_id(),
    kind.builtin_writer_id(),
    1L,
    1U,
    1U,
    [0x80000000U],
    0U,
  ).unwrap()
  assert_eq(
    sender.retransmit_nackfrag(prefix, wrapped, source).unwrap().length(),
    1,
  )
  assert_eq(
    sender.retransmit_nackfrag(prefix, nack, source).unwrap().length(),
    0,
  )
}

///|
test "lost discovery samples repair through periodic full history heartbeat and fragment requests" {
  let sender = sender_test_new()
  let remote = sender_test_remote()
  let endpoint = sender_test_endpoint(false)
  let kind = endpoint.kind()
  let reader = @core.ReliableDataReader::new(
    kind.builtin_reader_id(),
    kind.builtin_writer_id(),
  )
  // Drop all initial DATA and HEARTBEAT packets, then write another sample.
  ignore(sender.announce_sedp(endpoint, [remote], false).unwrap())
  let large = @discovery.SedpEndpointData::new(
    Publication,
    @core.Guid::new(
      endpoint.endpoint_guid().prefix(),
      @core.EntityId::new(b"xyz", 0x02).unwrap(),
    ),
    endpoint.topic_name(),
    endpoint.type_name(),
  ).unwrap()
  large.add_parameter(
    @discovery.qos_user_data(Bytes::from_array(Array::make(4000, 0x41))),
  )
  let initial = sender.announce_sedp(large, [remote], false).unwrap()
  for effect in initial {
    for submessage in effect.message.submessages() {
      if submessage.id() == DataFrag {
        let fragment = @core.DataFragSubmessage::from_submessage(submessage).unwrap()
        // Lose fragment two; keep all other fragments of sequence two.
        if fragment.fragment_starting_number() != 2U {
          assert_eq(reader.accept_data_frag(fragment).unwrap(), None)
        }
      }
    }
  }
  let periodic = sender.heartbeats([remote])
  let source = remote.metatraffic_unicast_locators()[0]
  let prefix = remote.participant_guid().prefix()
  let mut recovered_fragment_sample = false
  let mut recovered_first_sample = false
  for effect in periodic {
    for submessage in effect.message.submessages() {
      if submessage.id() == Heartbeat {
        let heartbeat = @core.HeartbeatSubmessage::from_submessage(submessage).unwrap()
        assert_eq(heartbeat.first_sequence_number(), 1L)
        assert_eq(heartbeat.last_sequence_number(), 2L)
        for request in reader.acknacks_for_heartbeat(heartbeat).unwrap() {
          let response = sender
            .retransmit_acknack(prefix, request, source)
            .unwrap()
          for resend in response {
            for submessage in resend.message.submessages() {
              if submessage.id() == Data {
                let data = @core.DataSubmessage::from_submessage(submessage).unwrap()
                assert_eq(data.writer_sequence_number(), 1L)
                reader.accept_data(data).unwrap()
                recovered_first_sample = true
              }
            }
          }
        }
      }
      if submessage.id() == HeartbeatFrag {
        let heartbeat = @core.HeartbeatFragSubmessage::from_submessage(
          submessage,
        ).unwrap()
        let requests = reader.nackfrags_for_heartbeat_frag(heartbeat).unwrap()
        assert_eq(requests.length(), 1)
        for request in requests {
          let response = sender
            .retransmit_nackfrag(prefix, request, source)
            .unwrap()
          assert_eq(response.length(), 1)
          let fragment = @core.DataFragSubmessage::from_submessage(
            response[0].message.submessages()[1],
          ).unwrap()
          assert_eq(fragment.fragment_starting_number(), 2U)
          let data = reader.accept_data_frag(fragment).unwrap().unwrap()
          assert_eq(data.writer_sequence_number(), 2L)
          assert_eq(
            @discovery.SedpEndpointData::from_data_submessage(Publication, data)
            .unwrap()
            .endpoint_guid(),
            large.endpoint_guid(),
          )
          recovered_fragment_sample = true
        }
      }
    }
  }
  assert_true(recovered_first_sample)
  assert_true(recovered_fragment_sample)
  assert_true(reader.has_received_sequence(1L))
  assert_true(reader.has_received_sequence(2L))
  assert_eq(sender.next_sedp_sequence_number(Publication), 3L)
}

///|
fn sender_test_ipv6_remote() -> @discovery.SpdpParticipantData {
  let remote = state_test_participant(2, 60, 0U)
  remote.add_metatraffic_unicast(
    @core.Locator::new(
      @core.LOCATOR_KIND_UDP_V6,
      7410U,
      Bytes::from_array(Array::make(16, 0)),
    ).unwrap(),
  )
  remote
}

///|
test "SEDP skips unsupported peers in either order and retains replay history" {
  let supported = sender_test_remote()
  let unsupported = sender_test_ipv6_remote()
  for remotes in [[unsupported, supported], [supported, unsupported]] {
    let sender = sender_test_new()
    let outputs = sender
      .announce_sedp(sender_test_endpoint(false), remotes, false)
      .unwrap()
    assert_eq(outputs.length(), 2)
    for output in outputs {
      assert_eq(output.destination, supported.metatraffic_unicast_locators()[0])
      assert_eq(
        output.message.destination_guid_prefix().unwrap(),
        Some(supported.participant_guid().prefix()),
      )
    }
    assert_eq(sender.next_sedp_sequence_number(Publication), 2L)
    assert_eq(sender.replay_sedp(supported).unwrap().length(), 2)
  }
}

///|
test "SEDP retains registration and tombstone with zero supported peers" {
  for remotes in [[], [sender_test_ipv6_remote()]] {
    let sender = sender_test_new()
    let endpoint = sender_test_endpoint(false)
    assert_eq(
      sender.announce_sedp(endpoint, remotes, false).unwrap().length(),
      0,
    )
    assert_eq(sender.next_sedp_sequence_number(Publication), 2L)
    let replay = sender.replay_sedp(sender_test_remote()).unwrap()
    assert_eq(replay.length(), 2)
    let data = @core.DataSubmessage::from_submessage(
      replay[0].message.submessages()[1],
    ).unwrap()
    assert_eq(data.writer_sequence_number(), 1L)
    assert_eq(data.status_info().unwrap(), None)
    assert_eq(
      sender.announce_sedp(endpoint, remotes, true).unwrap().length(),
      0,
    )
    assert_eq(sender.next_sedp_sequence_number(Publication), 3L)
    let replay = sender.replay_sedp(sender_test_remote()).unwrap()
    let data = @core.DataSubmessage::from_submessage(
      replay[0].message.submessages()[1],
    ).unwrap()
    assert_eq(data.writer_sequence_number(), 2L)
    assert_eq(
      data.status_info().unwrap(),
      Some(@core.STATUS_INFO_DISPOSED | @core.STATUS_INFO_UNREGISTERED),
    )
  }
}
