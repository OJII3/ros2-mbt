///|
fn limits_test_fragment(
  writer : @core.EntityId,
  reader : @core.EntityId,
  sequence : Int64,
  size : UInt32,
  fragment_size : Int32,
  number : UInt32,
) -> @core.DataFragSubmessage {
  @core.DataFragSubmessage::new(
    reader,
    writer,
    sequence,
    number,
    (1 : Int32).to_uint16(),
    fragment_size.to_uint16(),
    size,
    Bytes::from_array(Array::make(fragment_size, 0)),
  ).unwrap()
}

///|
test "discovery rejects oversized payload and bitmap claims before creating readers" {
  let engine = engine_test_new()
  let remote = engine_test_participant(1, 60)
  let kind = SedpEndpointKind::Publication
  for size in [DISCOVERY_MAX_SAMPLE_BYTES + 1U, 4097U] {
    let fragment = limits_test_fragment(
      kind.builtin_writer_id(),
      kind.builtin_reader_id(),
      1L,
      size,
      1,
      1U,
    )
    ignore(engine_test_receive(engine, remote, fragment.to_submessage(), 0L))
    assert_eq(engine.sedp_readers.length(), 0)
    assert_eq(engine.fragment_receive_usage(), (0, 0))
  }
  let fragment = limits_test_fragment(
    engine.writer_id,
    engine.reader_id,
    1L,
    DISCOVERY_MAX_SAMPLE_BYTES + 1U,
    1,
    1U,
  )
  ignore(engine_test_receive(engine, remote, fragment.to_submessage(), 0L))
  assert_eq(engine.spdp_fragment_readers.length(), 0)
}

///|
test "discovery incomplete sample count is shared across writers and rejected sequences remain retryable" {
  let engine = engine_test_new()
  let kind = SedpEndpointKind::Publication
  for index in 1..<=DISCOVERY_MAX_INCOMPLETE_SAMPLES {
    let remote = engine_test_participant(index.to_byte(), 60)
    let fragment = limits_test_fragment(
      kind.builtin_writer_id(),
      kind.builtin_reader_id(),
      1L,
      2U,
      1,
      1U,
    )
    ignore(engine_test_receive(engine, remote, fragment.to_submessage(), 0L))
  }
  assert_eq(engine.fragment_receive_usage().0, DISCOVERY_MAX_INCOMPLETE_SAMPLES)
  let remote = engine_test_participant(100, 60)
  let first = limits_test_fragment(
    engine.writer_id,
    engine.reader_id,
    1L,
    2U,
    1,
    1U,
  )
  ignore(engine_test_receive(engine, remote, first.to_submessage(), 0L))
  assert_eq(engine.spdp_fragment_readers.length(), 0)
  let finished = limits_test_fragment(
    kind.builtin_writer_id(),
    kind.builtin_reader_id(),
    1L,
    2U,
    1,
    2U,
  )
  ignore(
    engine_test_receive(
      engine,
      engine_test_participant(1, 60),
      finished.to_submessage(),
      0L,
    ),
  )
  assert_eq(
    engine.fragment_receive_usage().0,
    DISCOVERY_MAX_INCOMPLETE_SAMPLES - 1,
  )
  ignore(engine_test_receive(engine, remote, first.to_submessage(), 0L))
  assert_eq(engine.spdp_fragment_readers.length(), 1)
  assert_eq(engine.fragment_receive_usage().0, DISCOVERY_MAX_INCOMPLETE_SAMPLES)
}

///|
test "discovery aggregate payload and fragment presence storage is shared across SPDP and SEDP" {
  let engine = engine_test_new()
  let kind = SedpEndpointKind::Publication
  for index in 1..<=3 {
    let fragment = limits_test_fragment(
      kind.builtin_writer_id(),
      kind.builtin_reader_id(),
      1L,
      DISCOVERY_MAX_SAMPLE_BYTES,
      1024,
      1U,
    )
    ignore(
      engine_test_receive(
        engine,
        engine_test_participant(index.to_byte(), 60),
        fragment.to_submessage(),
        0L,
      ),
    )
  }
  assert_eq(engine.fragment_receive_usage(), (3, 3 * (1024 * 1024 + 1024 * 8)))
  let remote = engine_test_participant(100, 60)
  let fragment = limits_test_fragment(
    engine.writer_id,
    engine.reader_id,
    1L,
    DISCOVERY_MAX_SAMPLE_BYTES,
    1024,
    1U,
  )
  ignore(engine_test_receive(engine, remote, fragment.to_submessage(), 0L))
  assert_eq(engine.spdp_fragment_readers.length(), 0)
  engine.forget_remote_participant(
    engine_test_participant(1, 60).participant_guid(),
  )
  ignore(engine_test_receive(engine, remote, fragment.to_submessage(), 0L))
  assert_eq(engine.spdp_fragment_readers.length(), 1)
  assert_eq(engine.fragment_receive_usage().0, 3)
}

///|
test "undiscovered writer cap includes SPDP fragment state and heartbeat-only SEDP state" {
  let engine = engine_test_new()
  let fragment = limits_test_fragment(
    engine.writer_id,
    engine.reader_id,
    1L,
    2U,
    1,
    1U,
  )
  ignore(
    engine_test_receive(
      engine,
      engine_test_participant(200, 60),
      fragment.to_submessage(),
      0L,
    ),
  )
  let kind = SedpEndpointKind::Publication
  let heartbeat = @core.HeartbeatSubmessage::new(
    kind.builtin_reader_id(),
    kind.builtin_writer_id(),
    1L,
    1L,
    1U,
  ).unwrap()
  for index in 1..<=DISCOVERY_MAX_RECEIVE_WRITERS {
    ignore(
      engine_test_receive(
        engine,
        engine_test_participant(index.to_byte(), 60),
        heartbeat.to_submessage(),
        0L,
      ),
    )
  }
  assert_eq(engine.sedp_readers.length(), DISCOVERY_MAX_RECEIVE_WRITERS - 1)
  assert_eq(engine.spdp_fragment_readers.length(), 1)
  let overflow = engine_test_receive(
    engine,
    engine_test_participant(201, 60),
    fragment.to_submessage(),
    0L,
  )
  assert_eq(overflow.outgoing.length(), 0)
  assert_eq(engine.spdp_fragment_readers.length(), 1)
  let huge = @core.HeartbeatFragSubmessage::new(
    kind.builtin_reader_id(),
    kind.builtin_writer_id(),
    1L,
    0xFFFFFFFFU,
    1U,
  ).unwrap()
  let fresh = engine_test_new()
  let output = engine_test_receive(
    fresh,
    engine_test_participant(1, 60),
    huge.to_submessage(),
    0L,
  )
  assert_eq(output.outgoing.length(), 0)
  assert_eq(fresh.sedp_readers.length(), 0)
}

///|
test "reliable sample admission retries a rejected sequence after another sample completes" {
  let engine = engine_test_new()
  let remote = engine_test_participant(1, 60)
  let kind = SedpEndpointKind::Publication
  for sequence in 1..<=DISCOVERY_MAX_INCOMPLETE_SAMPLES {
    let fragment = limits_test_fragment(
      kind.builtin_writer_id(),
      kind.builtin_reader_id(),
      sequence.to_int64(),
      2U,
      1,
      1U,
    )
    ignore(engine_test_receive(engine, remote, fragment.to_submessage(), 0L))
  }
  let rejected_sequence = (DISCOVERY_MAX_INCOMPLETE_SAMPLES + 1).to_int64()
  let rejected = limits_test_fragment(
    kind.builtin_writer_id(),
    kind.builtin_reader_id(),
    rejected_sequence,
    2U,
    1,
    1U,
  )
  ignore(engine_test_receive(engine, remote, rejected.to_submessage(), 0L))
  let reader = engine.sedp_readers[0].reader
  assert_false(reader.has_received_sequence(rejected_sequence))
  assert_false(reader.has_incomplete_fragment(rejected_sequence))
  let final_fragment = limits_test_fragment(
    kind.builtin_writer_id(),
    kind.builtin_reader_id(),
    1L,
    2U,
    1,
    2U,
  )
  ignore(
    engine_test_receive(engine, remote, final_fragment.to_submessage(), 0L),
  )
  ignore(engine_test_receive(engine, remote, rejected.to_submessage(), 0L))
  assert_true(reader.has_incomplete_fragment(rejected_sequence))
  let final_fragment = limits_test_fragment(
    kind.builtin_writer_id(),
    kind.builtin_reader_id(),
    rejected_sequence,
    2U,
    1,
    2U,
  )
  ignore(
    engine_test_receive(engine, remote, final_fragment.to_submessage(), 0L),
  )
  assert_true(reader.has_received_sequence(rejected_sequence))
}

///|
test "unknown SPDP partial samples expire without traffic and free shared capacity" {
  let engine = engine_test_new()
  for cycle in 0..<3 {
    let now = cycle.to_int64() * DISCOVERY_SPDP_FRAGMENT_LIFETIME_MS
    for index in 1..<=DISCOVERY_MAX_INCOMPLETE_SAMPLES {
      let remote = engine_test_participant(index.to_byte(), 60)
      let first = limits_test_fragment(
        engine.writer_id,
        engine.reader_id,
        1L,
        2U,
        1,
        1U,
      )
      ignore(engine_test_receive(engine, remote, first.to_submessage(), now))
    }
    assert_eq(engine.participants().length(), 0)
    assert_eq(
      engine.fragment_receive_usage().0,
      DISCOVERY_MAX_INCOMPLETE_SAMPLES,
    )
    assert_eq(
      engine.next_deadline(),
      Some(now + DISCOVERY_SPDP_FRAGMENT_LIFETIME_MS),
    )
    // Repeated traffic must not extend the fixed deadline.
    let first = limits_test_fragment(
      engine.writer_id,
      engine.reader_id,
      1L,
      2U,
      1,
      1U,
    )
    ignore(
      engine_test_receive(
        engine,
        engine_test_participant(1, 60),
        first.to_submessage(),
        now + 1L,
      ),
    )
    assert_eq(
      engine.next_deadline(),
      Some(now + DISCOVERY_SPDP_FRAGMENT_LIFETIME_MS),
    )
    ignore(engine.advance(now + DISCOVERY_SPDP_FRAGMENT_LIFETIME_MS))
    assert_eq(engine.fragment_receive_usage(), (0, 0))
    assert_eq(engine.spdp_fragment_readers.length(), 0)
    assert_eq(engine.next_deadline(), None)
  }
  // Expiration also makes capacity available to a reliable SEDP writer, without
  // falsely acknowledging any of its sequences.
  let kind = SedpEndpointKind::Publication
  let remote = engine_test_participant(100, 60)
  let first = limits_test_fragment(
    kind.builtin_writer_id(),
    kind.builtin_reader_id(),
    1L,
    2U,
    1,
    1U,
  )
  ignore(engine_test_receive(engine, remote, first.to_submessage(), 15000L))
  assert_true(engine.sedp_readers[0].reader.has_incomplete_fragment(1L))
  ignore(engine.advance(20000L))
  assert_true(engine.sedp_readers[0].reader.has_incomplete_fragment(1L))
  assert_false(engine.sedp_readers[0].reader.has_received_sequence(1L))
}

///|
test "repeated fragmented SPDP completions use bounded best effort sequence tracking" {
  let engine = engine_test_new()
  let remote = engine_test_participant(1, 60)
  for port in 7400..<7500 {
    remote.add_metatraffic_unicast(
      @core.Locator::udp_v4(b"\x7F\x00\x00\x01", port.reinterpret_as_uint()).unwrap(),
    )
  }
  for sequence in 1..<=1024 {
    let data = remote.to_data_submessage(
      engine.reader_id,
      engine.writer_id,
      (sequence * 2).to_int64(),
    )
    let fragments = discovery_fragment_data(data).unwrap()
    assert_true(fragments.length() > 1)
    for fragment in fragments {
      ignore(engine_test_receive(engine, remote, fragment.to_submessage(), 0L))
    }
    assert_eq(engine.fragment_receive_usage(), (0, 0))
    assert_eq(engine.spdp_fragment_readers.length(), 1)
  }
  assert_eq(engine.participants().length(), 1)
  let reader = engine.spdp_fragment_readers[0].reader
  // Best-effort's bounded cutoff discards old holes as well as received samples.
  assert_true(reader.has_received_sequence(1L))
  assert_true(reader.has_received_sequence(2048L))
  assert_false(reader.has_received_sequence(2047L))
  assert_eq(reader.next_acknack_count(), 1U)
}
