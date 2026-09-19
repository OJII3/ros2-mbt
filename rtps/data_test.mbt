///|
fn test_entity_id(kind : Byte) -> Result[EntityId, String] {
  EntityId::new(b"abc", kind)
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
  let data = DataSubmessage::new(reader_id, writer_id, 7L, b"\x00\x01\x00\x00")
  let encoded = match data.to_submessage().to_bytes() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(
    encoded, b"\x15\x05\x18\x00\x00\x00\x10\x00abc\xC7abc\xC2\x07\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00",
  )
  let submessage = match Submessage::from_bytes(encoded) {
    Ok((value, _)) => value
    Err(message) => fail(message)
  }
  let decoded = match DataSubmessage::from_submessage(submessage) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded, data)
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
  let inline_qos = ParameterList::new()
  inline_qos.add(Parameter::new(PID_VENDOR_ID, b"\x01\x0F\x00\x00"))
  let data = DataSubmessage::new(reader_id, writer_id, 1L, b"payload").with_inline_qos(
    inline_qos.to_bytes(),
  )
  let submessage = match
    Submessage::from_bytes(
      match data.to_submessage().to_bytes() {
        Ok(value) => value
        Err(message) => fail(message)
      },
    ) {
    Ok((value, _)) => value
    Err(message) => fail(message)
  }
  let decoded = match DataSubmessage::from_submessage(submessage) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.inline_qos(), inline_qos.to_bytes())
  assert_eq(decoded.serialized_payload(), b"payload")
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
  let data = DataSubmessage::new(reader_id, writer_id, 1L, b"payload")
  let payload = data.to_payload()
  assert_eq(payload[0], 0)
  assert_eq(payload[1], 0)
  assert_eq(payload[2], 16)
  assert_eq(payload[3], 0)
  let decoded = match
    DataSubmessage::from_submessage(
      Submessage::new(SubmessageId::Data, data.flags(), payload),
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
    GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match EntityId::new(b"wrt", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let reader_id = match EntityId::new(b"rdr", 0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let identity = match SampleIdentity::new(Guid::new(prefix, writer_id), 9L) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let data = DataSubmessage::new(reader_id, writer_id, 1L, b"reply").with_related_sample_identity(
    identity,
  )
  let decoded = match
    DataSubmessage::from_submessage(
      match
        Submessage::from_bytes(
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
test "RTPS DATA rejects malformed flags and body" {
  let reader_id = match test_entity_id(0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match test_entity_id(0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let data = DataSubmessage::new(reader_id, writer_id, 1L, b"data")
  let payload = data.to_payload()
  assert_true(
    DataSubmessage::from_submessage(
      Submessage::new(SubmessageId::Data, 0x04, payload),
    )
    is Err(_),
  )
  assert_true(
    DataSubmessage::from_submessage(
      Submessage::new(SubmessageId::Data, 0x01, b"short"),
    )
    is Err(_),
  )
  assert_true(
    DataSubmessage::from_submessage(
      Submessage::new(SubmessageId::Heartbeat, 0x01, payload),
    )
    is Err(_),
  )
  assert_true(
    DataSubmessage::from_submessage(
      Submessage::new(SubmessageId::Data, 0x0D, data.to_payload()),
    )
    is Err(_),
  )
}

///|
test "DATA builds an RTPS message" {
  let prefix = match
    GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let reader_id = match EntityId::new(b"rdr", 0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match EntityId::new(b"wrt", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let data = DataSubmessage::new(reader_id, writer_id, 4L, b"payload")
  let message = data.to_message(prefix, VendorId::new(1, 15))
  assert_eq(message.submessages().length(), 1)
  let decoded = match
    DataSubmessage::from_submessage(message.submessages()[0]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded, data)
}
