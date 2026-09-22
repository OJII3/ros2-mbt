///|
test "RTPS message round trip" {
  let prefix = match
    @core.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let header = @core.Header::new(prefix, @core.VendorId::new(1, 15))
  let message = @core.Message::new(header)
  message.add(@core.Submessage::new(InfoTimestamp, 0x01, b"abcd"))
  message.add(@core.Submessage::new(Data, 0x05, b"payload"))
  let encoded = match message.to_bytes() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(
    encoded, b"RTPS\x02\x03\x01\x0F\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x09\x01\x04\x00abcd\x15\x05\x07\x00payload",
  )
  let decoded = match @core.Message::from_bytes(encoded) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.header().to_bytes(), header.to_bytes())
  assert_eq(decoded.submessages(), message.submessages())
}

///|
test "RTPS message inserts PAD before an unaligned following submessage" {
  let prefix = match
    @core.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let message = @core.Message::new(
    @core.Header::new(prefix, @core.VendorId::new(1, 15)),
  )
  message.add(@core.Submessage::new(InfoTimestamp, 0x01, b"abc"))
  message.add(@core.Submessage::new(Data, 0x05, b"payload"))
  let encoded = match message.to_bytes() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let decoded = match @core.Message::from_bytes(encoded) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.submessages().length(), 3)
  assert_eq(decoded.submessages()[0].id(), InfoTimestamp)
  assert_eq(decoded.submessages()[1].id(), Pad)
  assert_eq(decoded.submessages()[1].payload.length(), 1)
  assert_eq(decoded.submessages()[2].id(), Data)
}

///|
test "RTPS submessage uses big-endian length without little-endian flag" {
  let submessage = @core.Submessage::new(Data, 0, b"abc")
  let encoded = match submessage.to_bytes() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(encoded, b"\x15\x00\x00\x03abc")
  let decoded = match @core.Submessage::from_bytes(encoded) {
    Ok((value, _)) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded, submessage)
}

///|
test "RTPS message rejects truncated submessage" {
  assert_true(
    @core.Message::from_bytes(
      b"RTPS\x02\x03\x01\x0F\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x15\x01\x08",
    )
    is Err(_),
  )
}
