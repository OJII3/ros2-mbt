///|
test "RTPS header round trip" {
  let prefix = GuidPrefix::from_array([
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B,
  ])
  let prefix = match prefix {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let header = Header::new(prefix, VendorId::new(0x01, 0x0F))
  let encoded = header.to_bytes()
  assert_eq(encoded.length(), HEADER_LENGTH)
  assert_eq(encoded[0], b'R')
  assert_eq(encoded[4].to_int(), 2)
  assert_eq(encoded[7].to_int(), 15)
  let decoded = match Header::from_bytes(encoded) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.protocol_version, ProtocolVersion::new(2, 3))
  assert_eq(decoded.vendor_id, VendorId::new(1, 15))
  assert_eq(decoded.guid_prefix.as_bytes(), prefix.as_bytes())
}

///|
test "RTPS header rejects invalid input" {
  let result = Header::from_bytes(b"not an RTPS header")
  assert_true(result is Err(_))
  let result = GuidPrefix::new(b"short")
  assert_true(result is Err(_))
}

///|
test "RTPS submessage round trip" {
  let submessage = Submessage::new(Data, 0, b"payload").little_endian()
  let encoded = match submessage.to_bytes() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(encoded, b"\x15\x01\x07\x00payload")
  let (decoded, consumed) = match Submessage::from_bytes(encoded) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(consumed, encoded.length())
  assert_eq(decoded.id, Data)
  assert_eq(decoded.flags.to_int(), 1)
  assert_eq(decoded.payload, b"payload")
}

///|
test "RTPS submessage rejects truncation" {
  let result = Submessage::from_bytes(b"\x15\x01\x07")
  assert_true(result is Err(_))
}

///|
test "RTPS message accepts a PAD submessage" {
  let prefix = match
    GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let message = match
    Message::from_bytes(
      b"RTPS\x02\x03\x01\x0F\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x01\x01\x04\x00\x00\x00\x00\x00\x15\x01\x04\x00\x00\x00\x00\x00",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(message.header().guid_prefix(), prefix)
  assert_eq(message.submessages().length(), 2)
  assert_eq(message.submessages()[0].id(), Pad)
  assert_eq(message.submessages()[1].id(), Data)
}

///|
test "RTPS message preserves an unknown submessage and continues parsing" {
  let message = match
    Message::from_bytes(
      b"RTPS\x02\x03\x01\x0F\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x7F\x01\x02\x00\xAA\xBB\x15\x01\x04\x00\x00\x00\x00\x00",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(message.submessages().length(), 2)
  assert_eq(message.submessages()[0].id(), Unknown(0x7F))
  assert_eq(message.submessages()[1].id(), Data)
}

///|
test "RTPS final submessage with zero length consumes the remainder" {
  let message = match
    Message::from_bytes(
      b"RTPS\x02\x03\x01\x0F\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x15\x01\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x0C\x0D\x0E\x0F\x10\x11\x12\x13",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(message.submessages().length(), 1)
  assert_eq(message.submessages()[0].id(), Data)
  assert_eq(message.submessages()[0].payload.length(), 20)
}
