///|
test "RTPS INFO_DST round trips a GUID prefix" {
  let destination = InfoDestinationSubmessage::new(
    GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]).unwrap(),
  )
  let encoded = destination.to_submessage().to_bytes().unwrap()
  assert_eq(
    encoded,
    b"\x0E\x01\x0C\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B",
  )
  let decoded = InfoDestinationSubmessage::from_submessage(
    Submessage::from_bytes(encoded).unwrap().0,
  ).unwrap()
  assert_eq(decoded, destination)
}

///|
test "RTPS INFO_DST rejects non-prefix bodies" {
  assert_true(
    InfoDestinationSubmessage::from_submessage(
      Submessage::new(SubmessageId::InfoDestination, 0x01, b"short"),
    )
    is Err(_),
  )
}
