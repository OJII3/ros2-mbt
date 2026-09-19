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
  let submessage = Submessage::new(SubmessageId::Data, 0, b"payload").little_endian()
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
  assert_eq(decoded.id, SubmessageId::Data)
  assert_eq(decoded.flags.to_int(), 1)
  assert_eq(decoded.payload, b"payload")
}

///|
test "RTPS submessage rejects truncation" {
  let result = Submessage::from_bytes(b"\x15\x01\x07")
  assert_true(result is Err(_))
}
