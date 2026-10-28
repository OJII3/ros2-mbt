///|
fn history_test_remote(id : Byte) -> SpdpParticipantData {
  let remote = engine_test_participant(id, 60)
  remote.add_metatraffic_unicast(
    @core.Locator::udp_v4(b"\x7F\x00\x00\x01", 7410).unwrap(),
  )
  remote
}

///|
test "latest endpoint history is peer independent and compacted sequences answer GAP" {
  let engine = engine_test_new()
  let sender = engine.sender
  let a = engine_test_endpoint(engine.participant, 1)
  let b = engine_test_endpoint(engine.participant, 2)
  let peers = [history_test_remote(1), history_test_remote(2)]
  ignore(sender.announce_sedp(a, peers, false).unwrap())
  ignore(sender.announce_sedp(b, peers, false).unwrap())
  ignore(sender.announce_sedp(a, peers, false).unwrap())
  assert_eq(sender.writers[0].history.length(), 2)
  assert_eq(sender.next_sedp_sequence_number(Publication), 4L)
  let kind = SedpEndpointKind::Publication
  let ack = @core.AckNackSubmessage::new(
    kind.builtin_reader_id(),
    kind.builtin_writer_id(),
    1L,
    3U,
    [0xE0000000U],
    1U,
  ).unwrap()
  for peer in peers {
    let outputs = sender
      .retransmit_acknack(
        peer.participant_guid().prefix(),
        ack,
        peer.metatraffic_unicast_locators()[0],
      )
      .unwrap()
    assert_eq(outputs.length(), 3)
    let gap = @core.GapSubmessage::from_submessage(
      outputs[0].message.submessages()[1],
    ).unwrap()
    assert_true(gap.contains_sequence(1L))
    assert_true(!gap.contains_sequence(2L))
    assert_eq(
      @core.DataSubmessage::from_submessage(outputs[1].message.submessages()[1])
      .unwrap()
      .writer_sequence_number(),
      2L,
    )
    assert_eq(
      @core.DataSubmessage::from_submessage(outputs[2].message.submessages()[1])
      .unwrap()
      .writer_sequence_number(),
      3L,
    )
    let replay = sender.replay_sedp(peer).unwrap()
    assert_eq(replay.length(), 3)
    assert_eq(
      @core.DataSubmessage::from_submessage(replay[0].message.submessages()[1])
      .unwrap()
      .writer_sequence_number(),
      2L,
    )
    assert_eq(
      @core.DataSubmessage::from_submessage(replay[1].message.submessages()[1])
      .unwrap()
      .writer_sequence_number(),
      3L,
    )
    let heartbeat = @core.HeartbeatSubmessage::from_submessage(
      replay[2].message.submessages()[1],
    ).unwrap()
    assert_eq(heartbeat.first_sequence_number(), 2L)
    assert_eq(heartbeat.last_sequence_number(), 3L)
  }
  ignore(sender.announce_sedp(a, peers, true).unwrap())
  assert_eq(sender.writers[0].history.length(), 2)
  let replay = sender.replay_sedp(peers[1]).unwrap()
  let disposed = @core.DataSubmessage::from_submessage(
    replay[1].message.submessages()[1],
  ).unwrap()
  assert_eq(disposed.writer_sequence_number(), 4L)
  assert_eq(
    disposed.status_info().unwrap(),
    Some(@core.STATUS_INFO_DISPOSED | @core.STATUS_INFO_UNREGISTERED),
  )
  let request = @core.NackFragSubmessage::new(
    kind.builtin_reader_id(),
    kind.builtin_writer_id(),
    3L,
    1U,
    1U,
    [0x80000000U],
    1U,
  ).unwrap()
  let outputs = sender
    .retransmit_nackfrag(
      peers[0].participant_guid().prefix(),
      request,
      peers[0].metatraffic_unicast_locators()[0],
    )
    .unwrap()
  assert_eq(outputs.length(), 1)
  assert_true(
    @core.GapSubmessage::from_submessage(outputs[0].message.submessages()[1])
    .unwrap()
    .contains_sequence(3L),
  )
}

///|
test "sender supports IPv4 after unsupported unicast locators and multicast fallback" {
  let sender = engine_test_new().sender
  let endpoint = engine_test_endpoint(sender.participant, 1)
  let v6 = @core.Locator::new(
    @core.LOCATOR_KIND_UDP_V6,
    7410U,
    Bytes::from_array(Array::make(16, 1)),
  ).unwrap()
  let v4 = @core.Locator::udp_v4(b"\x7F\x00\x00\x01", 7410).unwrap()
  let mixed = engine_test_participant(1, 60)
  mixed.add_metatraffic_unicast(v6)
  mixed.add_metatraffic_unicast(v4)
  let fallback = engine_test_participant(2, 60)
  fallback.add_metatraffic_unicast(v6)
  fallback.add_metatraffic_multicast(v4)
  for remote in [mixed, fallback] {
    let outputs = sender.announce_sedp(endpoint, [remote], false).unwrap()
    assert_true(outputs.length() > 0)
    for output in outputs {
      assert_eq(output.destination, v4)
    }
    for output in sender.replay_sedp(remote).unwrap() {
      assert_eq(output.destination, v4)
    }
    for output in sender.heartbeats([remote]) {
      assert_eq(output.destination, v4)
    }
  }
  let unsupported = engine_test_participant(3, 60)
  unsupported.add_metatraffic_unicast(v6)
  let sequence = sender.next_sedp_sequence_number(Publication)
  assert_eq(
    sender.announce_sedp(endpoint, [unsupported], false).unwrap().length(),
    0,
  )
  assert_eq(sender.next_sedp_sequence_number(Publication), sequence + 1L)
}

///|
test "repeated endpoint updates keep bounded history and endpoint admission is atomic" {
  let sender = engine_test_new().sender
  let endpoint = engine_test_endpoint(sender.participant, 1)
  for _ in 0..<1100 {
    ignore(sender.announce_sedp(endpoint, [], false).unwrap())
  }
  assert_eq(sender.writers[0].history.length(), 1)
  for index in 1..<DISCOVERY_HISTORY_MAX_ENDPOINTS {
    let endpoint = SedpEndpointData::new(
      Publication,
      @core.Guid::new(
        sender.participant.participant_guid().prefix(),
        @core.EntityId::new(
          Bytes::from_array([index.to_byte(), (index >> 8).to_byte(), 1]),
          0x02,
        ).unwrap(),
      ),
      "rt/chatter",
      "std_msgs::msg::dds_::String_",
    ).unwrap()
    ignore(sender.announce_sedp(endpoint, [], false).unwrap())
  }
  assert_eq(sender.writers[0].history.length(), DISCOVERY_HISTORY_MAX_ENDPOINTS)
  let extra = engine_test_endpoint(sender.participant, 3)
  let sequence = sender.next_sedp_sequence_number(Publication)
  assert_true(sender.announce_sedp(extra, [], false) is Err(_))
  assert_eq(sender.next_sedp_sequence_number(Publication), sequence)
  // Replacing an existing endpoint remains allowed when entry capacity is full.
  ignore(sender.announce_sedp(endpoint, [], true).unwrap())
  assert_eq(sender.writers[0].history.length(), DISCOVERY_HISTORY_MAX_ENDPOINTS)
}

///|
test "SEDP history byte limit rejects a new write without changing sequences" {
  let sender = engine_test_new().sender
  let mut rejected = false
  let mut accepted = 0
  for index in 0..<32 {
    let endpoint = engine_test_endpoint(sender.participant, index.to_byte())
    for _ in 0..<10 {
      endpoint.add_parameter(
        qos_user_data(Bytes::from_array(Array::make(60000, 0x41))),
      )
    }
    let sequence = sender.next_sedp_sequence_number(Publication)
    match sender.announce_sedp(endpoint, [], false) {
      Ok(_) => accepted += 1
      Err(_) => {
        assert_eq(sender.next_sedp_sequence_number(Publication), sequence)
        rejected = true
        break
      }
    }
  }
  assert_true(rejected)
  assert_true(accepted > 0)
  let mut bytes = 0
  for write in sender.writers[0].history {
    bytes += discovery_write_bytes(write)
  }
  assert_true(bytes <= DISCOVERY_HISTORY_MAX_BYTES)
  assert_eq(sender.writers[0].history.length(), accepted)
}

///|
test "sender bounds control peers and ignores empty or unwritten history requests" {
  let sender = engine_test_new().sender
  let kind = SedpEndpointKind::Publication
  let source = @core.Locator::udp_v4(b"\x7F\x00\x00\x01", 7410).unwrap()
  let request = @core.AckNackSubmessage::new(
    kind.builtin_reader_id(),
    kind.builtin_writer_id(),
    1L,
    1U,
    [0x80000000U],
    1U,
  ).unwrap()
  let prefix = engine_test_participant(1, 60).participant_guid().prefix()
  assert_eq(
    sender.retransmit_acknack(prefix, request, source).unwrap().length(),
    0,
  )
  assert_eq(sender.controls.length(), 0)
  ignore(
    sender
    .announce_sedp(engine_test_endpoint(sender.participant, 1), [], false)
    .unwrap(),
  )
  let empty = @core.AckNackSubmessage::new(
    kind.builtin_reader_id(),
    kind.builtin_writer_id(),
    2L,
    0U,
    [],
    1U,
  ).unwrap()
  ignore(sender.retransmit_acknack(prefix, empty, source).unwrap())
  assert_eq(sender.controls.length(), 0)
  for index in 0..<(DISCOVERY_MAX_READER_CONTROLS + 1) {
    let prefix = @core.GuidPrefix::from_array([
      index.to_byte(),
      (index >> 8).to_byte(),
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
    ]).unwrap()
    let outputs = sender.retransmit_acknack(prefix, request, source).unwrap()
    assert_eq(
      outputs.length(),
      if index < DISCOVERY_MAX_READER_CONTROLS {
        1
      } else {
        0
      },
    )
  }
  assert_eq(sender.controls.length(), DISCOVERY_MAX_READER_CONTROLS)
  sender.forget_remote_participant(
    @core.GuidPrefix::from_array([0, 0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]).unwrap(),
  )
  assert_eq(sender.controls.length(), DISCOVERY_MAX_READER_CONTROLS - 1)
}

///|
test "sparse compacted history advertises whole GAP intervals to every peer" {
  let sender = engine_test_new().sender
  let a = engine_test_endpoint(sender.participant, 1)
  let b = engine_test_endpoint(sender.participant, 2)
  ignore(sender.announce_sedp(a, [], false).unwrap())
  for _ in 0..<2000 {
    ignore(sender.announce_sedp(b, [], false).unwrap())
  }
  assert_eq(sender.writers[0].history.length(), 2)
  let last = sender.next_sedp_sequence_number(Publication) - 1L
  let kind = SedpEndpointKind::Publication
  for peer in [history_test_remote(1), history_test_remote(2)] {
    for
      outputs in [sender.replay_sedp(peer).unwrap(), sender.heartbeats([peer])] {
      let mut gaps = 0
      for output in outputs {
        for submessage in output.message.submessages() {
          if submessage.id() == Gap {
            let gap = @core.GapSubmessage::from_submessage(submessage).unwrap()
            assert_eq(gap.gap_start(), 2L)
            assert_eq(gap.gap_list_base(), last)
            assert_eq(gap.gap_list_num_bits(), 0U)
            assert_true(!gap.contains_sequence(1L))
            assert_true(gap.contains_sequence(last - 1L))
            assert_true(!gap.contains_sequence(last))
            gaps += 1
          }
        }
      }
      assert_eq(gaps, 1)
    }
    let request = @core.AckNackSubmessage::new(
      kind.builtin_reader_id(),
      kind.builtin_writer_id(),
      300L,
      1U,
      [0x80000000U],
      1U,
    ).unwrap()
    let response = sender
      .retransmit_acknack(
        peer.participant_guid().prefix(),
        request,
        peer.metatraffic_unicast_locators()[0],
      )
      .unwrap()
    assert_eq(response.length(), 1)
    let gap = @core.GapSubmessage::from_submessage(
      response[0].message.submessages()[1],
    ).unwrap()
    assert_eq(gap.gap_start(), 2L)
    assert_eq(gap.gap_list_base(), last)
  }
}

///|
test "last SEDP sequence is admitted once even though next sequence cannot advance" {
  let sender = engine_test_new().sender
  sender.writer(Publication).next_sequence = 0x7FFFFFFFFFFFFFFFL
  let endpoint = engine_test_endpoint(sender.participant, 1)
  assert_true(sender.announce_sedp(endpoint, [], false) is Ok(_))
  assert_eq(sender.next_sedp_sequence_number(Publication), 0x7FFFFFFFFFFFFFFFL)
  assert_eq(sender.writers[0].history.length(), 1)
  assert_eq(
    sender.writers[0].history[0].data.writer_sequence_number(),
    0x7FFFFFFFFFFFFFFFL,
  )
  assert_true(sender.announce_sedp(endpoint, [], false) is Err(_))
  assert_eq(sender.writers[0].history.length(), 1)
}
