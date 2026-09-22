///|
fn test_entity_id(kind : Byte) -> Result[@core.EntityId, String] {
  @core.EntityId::new(b"abc", kind)
}

///|
test "RTPS DATA submessage round trip" {
  let reader_id = match test_entity_id(0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match test_entity_id(0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let data = @core.DataSubmessage::new(
    reader_id, writer_id, 7L, b"\x00\x01\x00\x00",
  )
  let encoded = match data.to_submessage().to_bytes() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(
    encoded, b"\x15\x05\x18\x00\x00\x00\x10\x00abc\xC7abc\xC2\x00\x00\x00\x00\x07\x00\x00\x00\x00\x01\x00\x00",
  )
  let submessage = match @core.Submessage::from_bytes(encoded) {
    Ok((value, _)) => value
    Err(message) => fail(message)
  }
  let decoded = match @core.DataSubmessage::from_submessage(submessage) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded, data)
}

///|
test "RTPS DATA parser accepts a big-endian body" {
  let reader_id = @core.EntityId::new(b"rdr", 0xC7).unwrap()
  let writer_id = @core.EntityId::new(b"wrt", 0xC2).unwrap()
  let submessage = @core.Submessage::new(
    Data,
    @core.DATA_FLAG_DATA,
    b"\x00\x00\x00\x10rdr\xC7wrt\xC2\x00\x00\x00\x00\x00\x00\x00\x01payload",
  )
  let decoded = @core.DataSubmessage::from_submessage(submessage).unwrap()
  assert_eq(
    decoded,
    @core.DataSubmessage::new(reader_id, writer_id, 1L, b"payload"),
  )
}

///|
test "RTPS DATA parser normalizes big-endian inline QoS" {
  let writer_id = @core.EntityId::new(b"wrt", 0xC2).unwrap()
  let prefix = @core.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let identity = @core.SampleIdentity::new(
    @core.Guid::new(prefix, writer_id),
    9L,
  ).unwrap()
  let inline_qos : Array[Byte] = [
    0x00, 0x71, 0x00, 0x04, 0x00, 0x00, 0x00, 0x01, 0x00, 0x83, 0x00, 0x18,
  ]
  let guid = identity.writer_guid().to_bytes()
  for byte in guid {
    inline_qos.push(byte)
  }
  for byte in [0, 0, 0, 0, 0, 0, 0, 9] {
    inline_qos.push(byte.to_byte())
  }
  for byte in [0x00, 0x01, 0x00, 0x00] {
    inline_qos.push(byte.to_byte())
  }
  let body : Array[Byte] = [
    0, 0, 0, 16, 0x72, 0x64, 0x72, 0xC7, 0x77, 0x72, 0x74, 0xC2, 0, 0, 0, 0, 0, 0,
    0, 1,
  ]
  for byte in inline_qos {
    body.push(byte)
  }
  for byte in b"key" {
    body.push(byte)
  }
  let decoded = @core.DataSubmessage::from_submessage(
    @core.Submessage::new(
      Data,
      @core.DATA_FLAG_DATA | @core.DATA_FLAG_INLINE_QOS,
      Bytes::from_array(body),
    ),
  ).unwrap()
  assert_eq(decoded.status_info(), Ok(Some(@core.STATUS_INFO_DISPOSED)))
  assert_eq(decoded.related_sample_identity(), Ok(Some(identity)))
  assert_eq(decoded.serialized_payload(), b"key")
}

///|
test "RTPS DATA supports inline QoS" {
  let reader_id = match test_entity_id(0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match test_entity_id(0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let inline_qos = @core.ParameterList::new()
  inline_qos.add(@core.Parameter::new(@core.PID_VENDOR_ID, b"\x01\x0F\x00\x00"))
  let data = @core.DataSubmessage::new(reader_id, writer_id, 1L, b"payload").with_inline_qos(
    inline_qos.to_bytes(),
  )
  let submessage = match
    @core.Submessage::from_bytes(
      match data.to_submessage().to_bytes() {
        Ok(value) => value
        Err(message) => fail(message)
      },
    ) {
    Ok((value, _)) => value
    Err(message) => fail(message)
  }
  let decoded = match @core.DataSubmessage::from_submessage(submessage) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.inline_qos(), inline_qos.to_bytes())
  assert_eq(decoded.serialized_payload(), b"payload")
}

///|
test "RTPS DATA_FRAG parser accepts a big-endian body" {
  let reader_id = @core.EntityId::new(b"rdr", 0xC7).unwrap()
  let writer_id = @core.EntityId::new(b"wrt", 0xC2).unwrap()
  let decoded = @core.DataFragSubmessage::from_submessage(
    @core.Submessage::new(
      DataFrag,
      @core.DATA_FLAG_DATA,
      b"\x00\x00\x00\x1Crdr\xC7wrt\xC2\x00\x00\x00\x00\x00\x00\x00\x09\x00\x00\x00\x01\x00\x01\x00\x04\x00\x00\x00\x04data",
    ),
  ).unwrap()
  assert_eq(decoded.reader_id(), reader_id)
  assert_eq(decoded.writer_id(), writer_id)
  assert_eq(decoded.writer_sequence_number(), 9L)
  assert_eq(decoded.fragment_starting_number(), 1U)
  assert_eq(decoded.fragments_in_submessage(), 1U.to_uint16())
  assert_eq(decoded.fragment_size(), 4U.to_uint16())
  assert_eq(decoded.sample_size(), 4U)
  assert_eq(decoded.serialized_payload(), b"data")
  assert_eq(
    decoded.flags(),
    @core.DATA_FLAG_LITTLE_ENDIAN | @core.DATA_FLAG_DATA,
  )
}

///|
test "RTPS DATA preserves extra flags and inline QoS offset wire order" {
  let reader_id = match test_entity_id(0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match test_entity_id(0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let data = @core.DataSubmessage::new(reader_id, writer_id, 1L, b"payload")
  let payload = data.to_payload()
  assert_eq(payload[0], 0)
  assert_eq(payload[1], 0)
  assert_eq(payload[2], 16)
  assert_eq(payload[3], 0)
  let decoded = match
    @core.DataSubmessage::from_submessage(
      @core.Submessage::new(Data, data.flags(), payload),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.extra_flags.to_int(), 0)
  assert_eq(decoded.octets_to_inline_qos.to_int(), 16)
}

///|
test "RTPS DATA carries a related sample identity" {
  let prefix = match
    @core.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match @core.EntityId::new(b"wrt", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let reader_id = match @core.EntityId::new(b"rdr", 0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let identity = match
    @core.SampleIdentity::new(@core.Guid::new(prefix, writer_id), 9L) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let data = @core.DataSubmessage::new(reader_id, writer_id, 1L, b"reply").with_related_sample_identity(
    identity,
  )
  let decoded = match
    @core.DataSubmessage::from_submessage(
      match
        @core.Submessage::from_bytes(
          match data.to_submessage().to_bytes() {
            Ok(value) => value
            Err(message) => fail(message)
          },
        ) {
        Ok((value, _)) => value
        Err(message) => fail(message)
      },
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.related_sample_identity(), Ok(Some(identity)))
  assert_eq(decoded.serialized_payload(), b"reply")
}

///|
test "RTPS DATA carries status info" {
  let reader_id = test_entity_id(0xC7).unwrap()
  let writer_id = test_entity_id(0xC2).unwrap()
  let status = @core.STATUS_INFO_DISPOSED | @core.STATUS_INFO_UNREGISTERED
  let data = @core.DataSubmessage::new(reader_id, writer_id, 1L, b"key").with_status_info(
    status,
  )
  let decoded = @core.DataSubmessage::from_submessage(
    @core.Submessage::from_bytes(data.to_submessage().to_bytes().unwrap()).unwrap().0,
  ).unwrap()
  assert_eq(decoded.status_info(), Ok(Some(status)))
  assert_eq(decoded.related_sample_identity(), Ok(None))
}

///|
test "RTPS DATA supports key-only payloads" {
  let reader_id = test_entity_id(0xC7).unwrap()
  let writer_id = test_entity_id(0xC2).unwrap()
  let data = @core.DataSubmessage::new(reader_id, writer_id, 1L, b"key").with_key(
    b"endpoint-key",
  )
  assert_eq(data.flags() & @core.DATA_FLAG_DATA, 0x00)
  assert_true((data.flags() & @core.DATA_FLAG_KEY) != 0x00)
  let decoded = @core.DataSubmessage::from_submessage(
    @core.Submessage::from_bytes(data.to_submessage().to_bytes().unwrap()).unwrap().0,
  ).unwrap()
  assert_eq(decoded.serialized_payload(), b"endpoint-key")
  assert_eq(decoded.flags(), data.flags())
}

///|
test "RTPS DATA rejects malformed flags and body" {
  let reader_id = match test_entity_id(0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match test_entity_id(0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let data = @core.DataSubmessage::new(reader_id, writer_id, 1L, b"data")
  let payload = data.to_payload()
  assert_true(
    @core.DataSubmessage::from_submessage(
      @core.Submessage::new(Data, 0x04, payload),
    )
    is Err(_),
  )
  assert_true(
    @core.DataSubmessage::from_submessage(
      @core.Submessage::new(Data, 0x01, b"short"),
    )
    is Err(_),
  )
  assert_true(
    @core.DataSubmessage::from_submessage(
      @core.Submessage::new(Heartbeat, 0x01, payload),
    )
    is Err(_),
  )
  assert_true(
    @core.DataSubmessage::from_submessage(
      @core.Submessage::new(Data, 0x0D, data.to_payload()),
    )
    is Err(_),
  )
}

///|
test "DATA builds an RTPS message" {
  let prefix = match
    @core.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let reader_id = match @core.EntityId::new(b"rdr", 0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match @core.EntityId::new(b"wrt", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let data = @core.DataSubmessage::new(reader_id, writer_id, 4L, b"payload")
  let message = data.to_message(prefix, @core.VendorId::new(1, 15))
  assert_eq(message.submessages().length(), 1)
  let decoded = match
    @core.DataSubmessage::from_submessage(message.submessages()[0]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded, data)
}

///|
test "RTPS DATA_FRAG round trips a final multi-fragment payload" {
  let reader_id = test_entity_id(0xC7).unwrap()
  let writer_id = test_entity_id(0xC2).unwrap()
  let data_frag = @core.DataFragSubmessage::new(
    reader_id,
    writer_id,
    7L,
    2U,
    (2 : Int).to_uint16(),
    (4 : Int).to_uint16(),
    10U,
    b"efghij",
  ).unwrap()
  let submessage = @core.Submessage::from_bytes(
      data_frag.to_submessage().to_bytes().unwrap(),
    ).unwrap().0
  let decoded = @core.DataFragSubmessage::from_submessage(submessage).unwrap()
  assert_eq(decoded.writer_sequence_number(), 7L)
  assert_eq(decoded.fragment_starting_number(), 2U)
  assert_eq(decoded.fragments_in_submessage(), (2 : Int).to_uint16())
  assert_eq(decoded.fragment_size(), (4 : Int).to_uint16())
  assert_eq(decoded.sample_size(), 10U)
  assert_eq(decoded.serialized_payload(), b"efghij")
  assert_eq(decoded, data_frag)
}

///|
test "RTPS DATA_FRAG rejects a short non-final fragment" {
  let reader_id = test_entity_id(0xC7).unwrap()
  let writer_id = test_entity_id(0xC2).unwrap()
  assert_true(
    @core.DataFragSubmessage::new(
      reader_id,
      writer_id,
      1L,
      1U,
      (1 : Int).to_uint16(),
      (4 : Int).to_uint16(),
      10U,
      b"abc",
    )
    is Err(_),
  )
}
