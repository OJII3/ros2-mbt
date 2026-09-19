///|
test "RTPS message round trip" {
  let prefix = match
    GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let header = Header::new(prefix, VendorId::new(1, 15))
  let message = Message::new(header)
  message.add(Submessage::new(SubmessageId::InfoTimestamp, 0x01, b"abcd"))
  message.add(Submessage::new(SubmessageId::Data, 0x05, b"payload"))
  let encoded = match message.to_bytes() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(
    encoded, b"RTPS\x02\x03\x01\x0F\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x09\x01\x04\x00abcd\x15\x05\x07\x00payload",
  )
  let decoded = match Message::from_bytes(encoded) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.header().to_bytes(), header.to_bytes())
  assert_eq(decoded.submessages(), message.submessages())
}

///|
test "RTPS message inserts PAD before an unaligned following submessage" {
  let prefix = match
    GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let message = Message::new(Header::new(prefix, VendorId::new(1, 15)))
  message.add(Submessage::new(SubmessageId::InfoTimestamp, 0x01, b"abc"))
  message.add(Submessage::new(SubmessageId::Data, 0x05, b"payload"))
  let encoded = match message.to_bytes() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let decoded = match Message::from_bytes(encoded) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.submessages().length(), 3)
  assert_eq(decoded.submessages()[0].id(), SubmessageId::InfoTimestamp)
  assert_eq(decoded.submessages()[1].id(), SubmessageId::Pad)
  assert_eq(decoded.submessages()[1].payload.length(), 1)
  assert_eq(decoded.submessages()[2].id(), SubmessageId::Data)
}

///|
test "RTPS submessage uses big-endian length without little-endian flag" {
  let submessage = Submessage::new(SubmessageId::Data, 0, b"abc")
  let encoded = match submessage.to_bytes() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(encoded, b"\x15\x00\x00\x03abc")
  let decoded = match Submessage::from_bytes(encoded) {
    Ok((value, _)) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded, submessage)
}

///|
test "RTPS message rejects truncated submessage" {
  assert_true(
    Message::from_bytes(
      b"RTPS\x02\x03\x01\x0F\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x15\x01\x08",
    )
    is Err(_),
  )
}
