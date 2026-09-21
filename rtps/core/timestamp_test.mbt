///|
test "RTPS INFO_TS little-endian round trip" {
  let timestamp = InfoTimestampSubmessage::new(-2, 0x12345678U)
  let encoded = match timestamp.to_submessage().to_bytes() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(encoded, b"\x09\x01\x08\x00\xFE\xFF\xFF\xFF\x78\x56\x34\x12")
  let decoded = match
    InfoTimestampSubmessage::from_submessage(
      match Submessage::from_bytes(encoded) {
        Ok((value, _)) => value
        Err(message) => fail(message)
      },
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded, timestamp)
}

///|
test "RTPS INFO_TS supports big-endian timestamps" {
  let submessage = Submessage::new(
    SubmessageId::InfoTimestamp,
    0,
    b"\xFF\xFF\xFF\xFE\x12\x34\x56\x78",
  )
  let decoded = match InfoTimestampSubmessage::from_submessage(submessage) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.seconds(), -2)
  assert_eq(decoded.fraction(), 0x12345678U)
  assert_true(decoded.is_valid())
}

///|
test "RTPS INFO_TS invalidation has no timestamp body" {
  let timestamp = InfoTimestampSubmessage::invalid()
  let encoded = match timestamp.to_submessage().to_bytes() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(encoded, b"\x09\x03\x00\x00")
  let decoded = match
    InfoTimestampSubmessage::from_submessage(
      match Submessage::from_bytes(encoded) {
        Ok((value, _)) => value
        Err(message) => fail(message)
      },
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_true(!decoded.is_valid())
  assert_eq(decoded.flags(), 0x03)
}

///|
test "RTPS INFO_TS rejects invalid body lengths" {
  assert_true(
    InfoTimestampSubmessage::from_submessage(
      Submessage::new(SubmessageId::InfoTimestamp, 0x01, b"short"),
    )
    is Err(_),
  )
  assert_true(
    InfoTimestampSubmessage::from_submessage(
      Submessage::new(SubmessageId::InfoTimestamp, 0x03, b"\x00"),
    )
    is Err(_),
  )
}
