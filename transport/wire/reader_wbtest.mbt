///|
fn best_effort_test_handle(
  reader : DataReader,
  submessage : @rtps.Submessage,
) -> @rtps.DataSubmessage? {
  let prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let message = @rtps.Message::new(
    @rtps.Header::new(prefix, @rtps.VendorId::new(1, 15)),
  )
  message.add(submessage)
  match
    reader
    .handle_message(message, @socket.Addr::new(0x7F000001U, 12345))
    .unwrap() {
    Some((data, _)) => Some(data)
    None => None
  }
}

///|
fn best_effort_test_data(
  reader : DataReader,
  sequence : Int64,
) -> @rtps.Submessage {
  @rtps.DataSubmessage::new(
    reader.reader_id,
    reader.writer_id,
    sequence,
    b"payload",
  ).to_submessage()
}

///|
fn best_effort_test_fragment(
  reader : DataReader,
  sequence : Int64,
  starting : UInt32,
  sample_size : UInt32,
) -> @rtps.Submessage {
  @rtps.DataFragSubmessage::new(
    @rtps.EntityId::unknown(),
    reader.writer_id,
    sequence,
    starting,
    (1 : Int32).to_uint16(),
    (4 : Int32).to_uint16(),
    sample_size,
    b"abcd",
  )
  .unwrap()
  .to_submessage()
}

///|
async test "best-effort history stays bounded and rejects duplicate and expired DATA" {
  let socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer socket.close()
  let reader = DataReader::new(
    socket,
    @rtps.EntityId::new(b"rdr", 0x04).unwrap(),
    @rtps.EntityId::new(b"wrt", 0x03).unwrap(),
  )
  for sequence in 1..<10001 {
    assert_true(
      best_effort_test_handle(
        reader,
        best_effort_test_data(reader, sequence.to_int64()),
      )
      is Some(_),
    )
    assert_true(reader.state.samples.length() <= 256)
  }
  assert_eq(reader.state.samples.length(), 256)
  assert_true(
    best_effort_test_handle(reader, best_effort_test_data(reader, 10000L))
    is None,
  )
  assert_true(
    best_effort_test_handle(reader, best_effort_test_data(reader, 1L)) is None,
  )
  assert_true(
    best_effort_test_handle(reader, best_effort_test_data(reader, 10256L))
    is Some(_),
  )
  assert_true(
    best_effort_test_handle(reader, best_effort_test_data(reader, 10001L))
    is Some(_),
  )
  assert_true(
    best_effort_test_handle(reader, best_effort_test_data(reader, 10001L))
    is None,
  )
  assert_true(
    best_effort_test_handle(reader, best_effort_test_data(reader, 10000L))
    is None,
  )
  assert_eq(reader.state.samples.length(), 2)
}

///|
async test "best-effort caps incomplete samples and preserves out-of-order fragments" {
  let socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer socket.close()
  let reader = DataReader::new(
    socket,
    @rtps.EntityId::new(b"rdr", 0x04).unwrap(),
    @rtps.EntityId::new(b"wrt", 0x03).unwrap(),
  )
  for sequence in 1..<1001 {
    assert_true(
      best_effort_test_handle(
        reader,
        best_effort_test_fragment(reader, sequence.to_int64(), 2U, 8U),
      )
      is None,
    )
    assert_true(reader.state.fragments.length() <= 4)
  }
  assert_eq(reader.state.fragments.length(), 4)
  assert_eq(reader.state.fragments[0].sequence_number, 997L)
  // An older sample cannot evict any of the four newer pending samples.
  assert_true(
    best_effort_test_handle(
      reader,
      best_effort_test_fragment(reader, 996L, 1U, 8U),
    )
    is None,
  )
  assert_eq(reader.state.fragments[0].sequence_number, 997L)
  let data = best_effort_test_handle(
    reader,
    best_effort_test_fragment(reader, 1000L, 1U, 8U),
  ).unwrap()
  assert_eq(data.serialized_payload(), b"abcdabcd")
  assert_eq(reader.state.fragments.length(), 3)
  assert_true(
    best_effort_test_handle(
      reader,
      best_effort_test_fragment(reader, 1000L, 1U, 8U),
    )
    is None,
  )
  // Completing a sample with unfragmented DATA also frees its partial assembly.
  assert_true(
    best_effort_test_handle(reader, best_effort_test_data(reader, 999L))
    is Some(_),
  )
  assert_eq(reader.state.fragments.length(), 2)
  // A large sequence jump expires the remaining partial samples.
  assert_true(
    best_effort_test_handle(reader, best_effort_test_data(reader, 1255L))
    is Some(_),
  )
  assert_eq(reader.state.fragments.length(), 0)
}

///|
async test "best-effort enforces its reassembly payload budget before allocating" {
  let socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer socket.close()
  let reader = DataReader::new(
    socket,
    @rtps.EntityId::new(b"rdr", 0x04).unwrap(),
    @rtps.EntityId::new(b"wrt", 0x03).unwrap(),
  )
  assert_true(
    best_effort_test_handle(
      reader,
      best_effort_test_fragment(reader, 1L, 1U, 16U * 1024U * 1024U + 1U),
    )
    is None,
  )
  assert_eq(reader.state.fragments.length(), 0)
  let payload = Bytes::from_array(Array::make(1024, 0))
  for sequence in 1..<4 {
    let fragment = @rtps.DataFragSubmessage::new(
      reader.reader_id,
      reader.writer_id,
      sequence.to_int64(),
      1U,
      (1 : Int32).to_uint16(),
      (1024 : Int32).to_uint16(),
      8U * 1024U * 1024U,
      payload,
    ).unwrap()
    assert_true(
      best_effort_test_handle(reader, fragment.to_submessage()) is None,
    )
  }
  assert_eq(reader.state.fragments.length(), 2)
  assert_eq(reader.state.fragments[0].sequence_number, 2L)
  let mut payload_bytes = 0
  for sample in reader.state.fragments {
    payload_bytes += sample.sample_size
  }
  assert_eq(payload_bytes, 16 * 1024 * 1024)
}
