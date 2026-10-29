///|
fn engine_test_participant(id : Byte, seconds : Int32) -> SpdpParticipantData {
  let prefix = @core.GuidPrefix::from_array([
    id, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  SpdpParticipantData::new(
    @core.Guid::new(prefix, @core.EntityId::new(b"abc", 0xC1).unwrap()),
    @core.VendorId::new(1, 15),
    0,
    seconds,
    0U,
    3U,
  )
}

///|
fn engine_test_new() -> DiscoveryEngine {
  DiscoveryEngine::new(
    engine_test_participant(0, 60),
    @core.EntityId::new(
      b"\x00\x01\x00",
      ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
    ).unwrap(),
    @core.EntityId::new(
      b"\x00\x01\x00",
      ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
    ).unwrap(),
    @core.Locator::udp_v4(b"\x7F\x00\x00\x01", 7400).unwrap(),
    1L,
  ).unwrap()
}

///|
fn engine_test_endpoint(
  remote : SpdpParticipantData,
  id : Byte,
) -> SedpEndpointData {
  SedpEndpointData::new(
    Publication,
    @core.Guid::new(
      remote.participant_guid().prefix(),
      @core.EntityId::new([id, 0, 0] |> Bytes::from_array, 0x02).unwrap(),
    ),
    "rt/chatter",
    "std_msgs::msg::dds_::String_",
  )
  .unwrap()
  .with_participant_guid(remote.participant_guid())
}

///|
fn engine_test_receive(
  engine : DiscoveryEngine,
  remote : SpdpParticipantData,
  submessage : @core.Submessage,
  now_ms : Int64,
) -> DiscoveryEffects {
  let message = @core.Message::new(
    @core.Header::new(remote.participant_guid().prefix(), remote.vendor_id()),
  )
  message.add(submessage)
  engine
  .receive(
    message,
    @core.Locator::udp_v4(b"\x7F\x00\x00\x01", 7410).unwrap(),
    now_ms,
  )
  .unwrap()
}

///|
fn engine_test_data(
  endpoint : SedpEndpointData,
  sequence : Int64,
) -> @core.DataSubmessage {
  let kind = endpoint.kind()
  endpoint
  .to_data_submessage(
    kind.builtin_reader_id(),
    kind.builtin_writer_id(),
    sequence,
  )
  .unwrap()
}

///|
test "SEDP suppresses duplicate and stale endpoint changes but acknowledges received sequences" {
  let engine = engine_test_new()
  let remote = engine_test_participant(1, 60)
  let endpoint = engine_test_endpoint(remote, 1)
  let newer = engine_test_data(endpoint, 3L)
  assert_true(
    engine_test_receive(engine, remote, newer.to_submessage(), 0L).events[0]
    is Publication(_),
  )
  assert_eq(
    engine_test_receive(engine, remote, newer.to_submessage(), 0L).events.length(),
    0,
  )
  let stale = engine_test_data(endpoint, 1L)
  assert_eq(
    engine_test_receive(engine, remote, stale.to_submessage(), 0L).events.length(),
    0,
  )
  // Sequence order is per endpoint: a different endpoint at sequence 2 is new.
  let other = engine_test_data(engine_test_endpoint(remote, 2), 2L)
  assert_eq(
    engine_test_receive(engine, remote, other.to_submessage(), 0L).events.length(),
    1,
  )
  let kind = SedpEndpointKind::Publication
  let dispose = endpoint.to_dispose_data_submessage(
    kind.builtin_reader_id(),
    kind.builtin_writer_id(),
    5L,
  )
  assert_true(
    engine_test_receive(engine, remote, dispose.to_submessage(), 0L).events[0]
    is EndpointRemoved(_, _),
  )
  assert_eq(
    engine_test_receive(engine, remote, dispose.to_submessage(), 0L).events.length(),
    0,
  )
  assert_eq(
    engine_test_receive(
      engine,
      remote,
      engine_test_data(endpoint, 4L).to_submessage(),
      0L,
    ).events.length(),
    0,
  )
  let heartbeat = @core.HeartbeatSubmessage::new(
    kind.builtin_reader_id(),
    kind.builtin_writer_id(),
    1L,
    5L,
    1U,
  ).unwrap()
  let effects = engine_test_receive(
    engine,
    remote,
    heartbeat.to_submessage(),
    0L,
  )
  let submessages = effects.outgoing[0].message.submessages()
  let ack = @core.AckNackSubmessage::from_submessage(
    submessages[submessages.length() - 1],
  ).unwrap()
  assert_eq(ack.bitmap_base(), 6L)
  assert_eq(ack.num_bits(), 0U)
  // An old dispose must not remove a subsequently updated endpoint.
  assert_eq(
    engine_test_receive(
      engine,
      remote,
      engine_test_data(endpoint, 8L).to_submessage(),
      0L,
    ).events.length(),
    1,
  )
  let old_dispose = endpoint.to_dispose_data_submessage(
    kind.builtin_reader_id(),
    kind.builtin_writer_id(),
    7L,
  )
  assert_eq(
    engine_test_receive(engine, remote, old_dispose.to_submessage(), 0L).events.length(),
    0,
  )
}

///|
test "completed SEDP fragments deliver exactly once and preserve endpoint order" {
  let engine = engine_test_new()
  let remote = engine_test_participant(1, 60)
  let endpoint = engine_test_endpoint(remote, 1)
  endpoint.add_parameter(
    qos_user_data(Bytes::from_array(Array::make(4000, 0x41))),
  )
  let data = engine_test_data(endpoint, 2L)
  let fragments = discovery_fragment_data(data).unwrap()
  assert_true(fragments.length() > 1)
  for index in 0..<fragments.length() {
    let effects = engine_test_receive(
      engine,
      remote,
      fragments[index].to_submessage(),
      0L,
    )
    assert_eq(
      effects.events.length(),
      if index + 1 == fragments.length() {
        1
      } else {
        0
      },
    )
  }
  for fragment in fragments {
    assert_eq(
      engine_test_receive(engine, remote, fragment.to_submessage(), 0L).events.length(),
      0,
    )
  }
  assert_eq(
    engine_test_receive(engine, remote, data.to_submessage(), 0L).events.length(),
    0,
  )
  assert_eq(
    engine_test_receive(
      engine,
      remote,
      engine_test_data(endpoint, 1L).to_submessage(),
      0L,
    ).events.length(),
    0,
  )
}

///|
fn engine_test_seed_remote(
  engine : DiscoveryEngine,
  remote : SpdpParticipantData,
) -> Unit {
  ignore(
    engine_test_receive(
      engine,
      remote,
      remote
      .to_data_submessage(engine.reader_id, engine.writer_id, 1L)
      .to_submessage(),
      0L,
    ),
  )
  ignore(
    engine_test_receive(
      engine,
      remote,
      engine_test_data(engine_test_endpoint(remote, 1), 20L).to_submessage(),
      0L,
    ),
  )
  let fragment = @core.DataFragSubmessage::new(
    engine.reader_id,
    engine.writer_id,
    2L,
    1U,
    (1 : Int32).to_uint16(),
    (4 : Int32).to_uint16(),
    8U,
    b"abcd",
  ).unwrap()
  ignore(engine_test_receive(engine, remote, fragment.to_submessage(), 0L))
  let kind = SedpEndpointKind::Publication
  let ack = @core.AckNackSubmessage::new(
    kind.builtin_reader_id(),
    kind.builtin_writer_id(),
    1L,
    1U,
    [0x80000000U],
    1U,
  ).unwrap()
  ignore(engine_test_receive(engine, remote, ack.to_submessage(), 0L))
}

///|
test "participant expiry and dispose clear only that participant reliability and endpoint highwater" {
  let engine = engine_test_new()
  ignore(
    engine
    .announce_sedp(engine_test_endpoint(engine.participant, 9), [], false)
    .unwrap(),
  )
  let remote = engine_test_participant(1, 1)
  let other = engine_test_participant(2, 60)
  engine_test_seed_remote(engine, remote)
  engine_test_seed_remote(engine, other)
  assert_eq(engine.sedp_readers.length(), 2)
  assert_eq(engine.spdp_fragment_readers.length(), 2)
  assert_eq(engine.sender.controls.length(), 2)
  let effects = engine.advance(1000L)
  assert_true(
    effects.events[0] is ParticipantRemoved(guid) &&
    guid == remote.participant_guid(),
  )
  assert_eq(engine.sedp_readers.length(), 1)
  assert_eq(engine.sender.controls.length(), 1)
  assert_eq(engine.sender.controls[0].prefix, other.participant_guid().prefix())
  assert_eq(
    engine.sedp_readers[0].writer_prefix,
    other.participant_guid().prefix(),
  )
  assert_eq(engine.spdp_fragment_readers.length(), 1)
  assert_eq(
    engine.spdp_fragment_readers[0].writer_prefix,
    other.participant_guid().prefix(),
  )
  ignore(
    engine_test_receive(
      engine,
      remote,
      remote
      .to_data_submessage(engine.reader_id, engine.writer_id, 1L)
      .to_submessage(),
      1001L,
    ),
  )
  assert_eq(
    engine_test_receive(
      engine,
      remote,
      engine_test_data(engine_test_endpoint(remote, 1), 1L).to_submessage(),
      1001L,
    ).events.length(),
    1,
  )
  let disposed = remote.to_dispose_data_submessage(
    engine.reader_id,
    engine.writer_id,
    2L,
  )
  let effects = engine_test_receive(
    engine,
    remote,
    disposed.to_submessage(),
    1002L,
  )
  assert_true(
    effects.events[0] is ParticipantRemoved(guid) &&
    guid == remote.participant_guid(),
  )
  assert_eq(engine.sedp_readers.length(), 1)
  assert_eq(engine.spdp_fragment_readers.length(), 1)
}

///|
test "ready announcement expires participant before rediscovery at the exact deadline" {
  let engine = engine_test_new()
  let remote = engine_test_participant(1, 1)
  engine_test_seed_remote(engine, remote)
  let effects = engine_test_receive(
    engine,
    remote,
    remote
    .to_data_submessage(engine.reader_id, engine.writer_id, 2L)
    .to_submessage(),
    1000L,
  )
  assert_eq(effects.events.length(), 2)
  assert_true(effects.events[0] is ParticipantRemoved(_))
  assert_true(effects.events[1] is Participant(_))
  assert_eq(engine.sedp_readers.length(), 0)
  assert_eq(engine.spdp_fragment_readers.length(), 0)
  assert_eq(engine.participants().length(), 1)
  assert_eq(engine.next_deadline(), Some(2000L))
}

///|
test "INFO_DST switches routing in submessage order including heartbeat responses" {
  let engine = engine_test_new()
  let remote = engine_test_participant(1, 60)
  let foreign = engine_test_participant(2, 60).participant_guid().prefix()
  let local_prefix = engine.participant.participant_guid().prefix()
  let unknown = @core.GuidPrefix::from_array(Array::make(12, 0)).unwrap()
  let kind = SedpEndpointKind::Publication
  let message = @core.Message::new(
    @core.Header::new(remote.participant_guid().prefix(), remote.vendor_id()),
  )
  // Foreign contexts must neither deliver DATA nor change ACK receive state.
  for
    (destination, sequence) in [
      (foreign, 1L),
      (local_prefix, 2L),
      (foreign, 3L),
      (unknown, 4L),
    ] {
    message.add(
      @core.InfoDestinationSubmessage::new(destination).to_submessage(),
    )
    message.add(
      engine_test_data(
        engine_test_endpoint(remote, sequence.to_int().to_byte()),
        sequence,
      ).to_submessage(),
    )
    message.add(
      @core.HeartbeatSubmessage::new(
        kind.builtin_reader_id(),
        kind.builtin_writer_id(),
        1L,
        sequence,
        sequence.to_int().reinterpret_as_uint(),
      )
      .unwrap()
      .to_submessage(),
    )
  }
  let source = @core.Locator::udp_v4(b"\x7F\x00\x00\x01", 7410).unwrap()
  let effects = engine.receive(message, source, 0L).unwrap()
  assert_eq(effects.events.length(), 2)
  assert_true(
    effects.events[0] is Publication(endpoint) &&
    endpoint.endpoint_guid() == engine_test_endpoint(remote, 2).endpoint_guid(),
  )
  assert_true(
    effects.events[1] is Publication(endpoint) &&
    endpoint.endpoint_guid() == engine_test_endpoint(remote, 4).endpoint_guid(),
  )
  assert_eq(effects.outgoing.length(), 2)
  for index in 0..<effects.outgoing.length() {
    let output = effects.outgoing[index]
    assert_eq(output.destination, source)
    assert_eq(
      output.message.destination_contexts().unwrap()[0],
      Some(remote.participant_guid().prefix()),
    )
    let submessages = output.message.submessages()
    let ack = @core.AckNackSubmessage::from_submessage(
      submessages[submessages.length() - 1],
    ).unwrap()
    assert_eq(ack.count(), (index + 1).reinterpret_as_uint())
    assert_eq(ack.bitmap_base(), 1L)
    assert_eq(ack.num_bits(), if index == 0 { 2U } else { 4U })
    assert_eq(
      ack.bitmap(),
      if index == 0 {
        [0x80000000U]
      } else {
        [0xA0000000U]
      },
    )
  }
  // INFO_DST context does not leak into the following datagram.
  let ending_foreign = @core.Message::new(
    @core.Header::new(remote.participant_guid().prefix(), remote.vendor_id()),
  )
  ending_foreign.add(
    @core.InfoDestinationSubmessage::new(foreign).to_submessage(),
  )
  assert_eq(
    engine.receive(ending_foreign, source, 0L).unwrap().events.length(),
    0,
  )
  let delivered = engine_test_receive(
    engine,
    remote,
    engine_test_data(engine_test_endpoint(remote, 1), 1L).to_submessage(),
    0L,
  )
  assert_eq(delivered.events.length(), 1)
}

///|
test "malformed destination preserves earlier effects and suppresses ambiguous routing" {
  let engine = engine_test_new()
  let remote = engine_test_participant(1, 60)
  let source = @core.Locator::udp_v4(b"\x7F\x00\x00\x01", 7410).unwrap()
  let message = @core.Message::new(
    @core.Header::new(remote.participant_guid().prefix(), remote.vendor_id()),
  )
  message.add(
    engine_test_data(engine_test_endpoint(remote, 1), 1L).to_submessage(),
  )
  message.add(@core.Submessage::new(InfoDestination, 1, b"short"))
  message.add(
    engine_test_data(engine_test_endpoint(remote, 2), 2L).to_submessage(),
  )
  message.add(
    @core.InfoDestinationSubmessage::new(
      engine.participant.participant_guid().prefix(),
    ).to_submessage(),
  )
  message.add(
    engine_test_data(engine_test_endpoint(remote, 3), 3L).to_submessage(),
  )
  let effects = engine.receive(message, source, 0L).unwrap()
  assert_eq(effects.events.length(), 2)
  assert_true(
    effects.events[0] is Publication(endpoint) &&
    endpoint.endpoint_guid() == engine_test_endpoint(remote, 1).endpoint_guid(),
  )
  assert_true(
    effects.events[1] is Publication(endpoint) &&
    endpoint.endpoint_guid() == engine_test_endpoint(remote, 3).endpoint_guid(),
  )
}

///|
test "virtual engines recover dropped history and fragments through clock-driven control exchange" {
  let writer = engine_test_new()
  let local_participant = writer.participant
  let remote = engine_test_participant(1, 60)
  let reader = DiscoveryEngine::new(
    remote,
    writer.reader_id,
    writer.writer_id,
    writer.sender.destination,
    1L,
  ).unwrap()
  let source = @core.Locator::udp_v4(b"\x7F\x00\x00\x01", 7410).unwrap()
  local_participant.add_metatraffic_unicast(source)
  remote.add_metatraffic_unicast(source)
  ignore(
    engine_test_receive(
      writer,
      remote,
      remote
      .to_data_submessage(writer.reader_id, writer.writer_id, 1L)
      .to_submessage(),
      0L,
    ),
  )
  ignore(
    engine_test_receive(
      reader,
      local_participant,
      local_participant
      .to_data_submessage(reader.reader_id, reader.writer_id, 1L)
      .to_submessage(),
      0L,
    ),
  )
  let first = engine_test_endpoint(local_participant, 1)
  // Lose the first sample and all of its initial heartbeats.
  let lost = writer.announce_sedp(first, [remote], false).unwrap()
  let large = engine_test_endpoint(local_participant, 2)
  large.add_parameter(qos_user_data(Bytes::from_array(Array::make(4000, 0x41))))
  for output in writer.announce_sedp(large, [remote], false).unwrap() {
    for submessage in output.message.submessages() {
      if submessage.id() != DataFrag {
        continue
      }
      let fragment = @core.DataFragSubmessage::from_submessage(submessage).unwrap()
      if fragment.fragment_starting_number() != 2U {
        assert_eq(
          engine_test_receive(reader, local_participant, submessage, 0L).events.length(),
          0,
        )
      }
    }
  }
  assert_eq(writer.next_deadline(), Some(0L))
  let periodic = writer.advance(10L)
  assert_eq(writer.next_deadline(), Some(1010L))
  assert_eq(writer.advance(1009L).outgoing.length(), 0)
  let controls : Array[DiscoveryOutput] = []
  for output in periodic.outgoing {
    for control in reader.receive(output.message, source, 10L).unwrap().outgoing {
      controls.push(control)
    }
  }
  let recovered : Array[DiscoveryEvent] = []
  // Repair the missing fragment first, then repair the entirely lost DATA.
  for
    control_kind in [@core.SubmessageId::NackFrag, @core.SubmessageId::AckNack] {
    for control in controls {
      if !control.message
        .submessages()
        .any(fn(submessage) { submessage.id() == control_kind }) {
        continue
      }
      let replies = writer.receive(control.message, source, 10L).unwrap()
      for reply in replies.outgoing {
        for event in reader.receive(reply.message, source, 10L).unwrap().events {
          recovered.push(event)
        }
      }
    }
  }
  assert_eq(recovered.length(), 2)
  assert_true(
    recovered[0] is Publication(endpoint) &&
    endpoint.endpoint_guid() == large.endpoint_guid(),
  )
  assert_true(
    recovered[1] is Publication(endpoint) &&
    endpoint.endpoint_guid() == first.endpoint_guid(),
  )
  for output in writer.announce_sedp(first, [remote], true).unwrap() {
    let effects = reader.receive(output.message, source, 11L).unwrap()
    for event in effects.events {
      assert_true(
        event is EndpointRemoved(_, guid) && guid == first.endpoint_guid(),
      )
    }
  }
  for output in lost {
    assert_eq(
      reader.receive(output.message, source, 12L).unwrap().events.length(),
      0,
    )
  }
  assert_eq(writer.next_sedp_sequence_number(Publication), 4L)
}

///|
test "SEDP retransmissions use the advertised metatraffic locator rather than packet source" {
  let engine = engine_test_new()
  let remote = engine_test_participant(1, 60)
  let advertised = @core.Locator::udp_v4(b"\x7F\x00\x00\x01", 7450).unwrap()
  remote.add_metatraffic_unicast(advertised)
  ignore(
    engine_test_receive(
      engine,
      remote,
      remote
      .to_data_submessage(engine.reader_id, engine.writer_id, 1L)
      .to_submessage(),
      0L,
    ),
  )
  let endpoint = engine_test_endpoint(engine.participant, 1)
  endpoint.add_parameter(
    qos_user_data(Bytes::from_array(Array::make(4000, 0x41))),
  )
  ignore(engine.announce_sedp(endpoint, [remote], false).unwrap())
  let kind = endpoint.kind()
  let controls = [
    @core.AckNackSubmessage::new(
      kind.builtin_reader_id(),
      kind.builtin_writer_id(),
      1L,
      1U,
      [0x80000000U],
      1U,
    )
    .unwrap()
    .to_submessage(),
    @core.NackFragSubmessage::new(
      kind.builtin_reader_id(),
      kind.builtin_writer_id(),
      1L,
      2U,
      1U,
      [0x80000000U],
      1U,
    )
    .unwrap()
    .to_submessage(),
  ]
  for control in controls {
    let effects = engine_test_receive(engine, remote, control, 1L)
    assert_true(effects.outgoing.length() > 0)
    for output in effects.outgoing {
      assert_eq(output.destination, advertised)
      assert_eq(
        output.message.destination_contexts().unwrap()[0],
        Some(remote.participant_guid().prefix()),
      )
    }
  }
}

///|
test "discovery acknowledgements select the configured transport family from dual-stack locators" {
  let engine = engine_test_new()
  let remote = engine_test_participant(1, 60)
  remote.add_metatraffic_unicast(
    @core.Locator::new(
      @core.LOCATOR_KIND_UDP_V6,
      7450U,
      Bytes::from_array(Array::make(16, 0)),
    ).unwrap(),
  )
  let ipv4 = @core.Locator::udp_v4(b"\x7F\x00\x00\x01", 7450).unwrap()
  remote.add_metatraffic_unicast(ipv4)
  ignore(
    engine_test_receive(
      engine,
      remote,
      remote
      .to_data_submessage(engine.reader_id, engine.writer_id, 1L)
      .to_submessage(),
      0L,
    ),
  )
  let kind = SedpEndpointKind::Publication
  let effects = engine_test_receive(
    engine,
    remote,
    @core.HeartbeatSubmessage::new(
      kind.builtin_reader_id(),
      kind.builtin_writer_id(),
      1L,
      1L,
      1U,
    )
    .unwrap()
    .to_submessage(),
    0L,
  )
  assert_eq(effects.outgoing.length(), 1)
  assert_eq(effects.outgoing[0].destination, ipv4)
}
