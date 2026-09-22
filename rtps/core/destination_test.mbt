///|
test "RTPS INFO_DST round trips a GUID prefix" {
  let destination = InfoDestinationSubmessage::new(
    GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]).unwrap(),
  )
  let encoded = destination.to_submessage().to_bytes().unwrap()
  assert_eq(
    encoded, b"\x0E\x01\x0C\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B",
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
      Submessage::new(InfoDestination, 0x01, b"short"),
    )
    is Err(_),
  )
}

///|
test "RTPS message exposes its optional INFO_DST prefix" {
  let prefix = GuidPrefix::from_array([11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]).unwrap()
  let message = Message::new(
    Header::new(
      GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]).unwrap(),
      VendorId::new(1, 15),
    ),
  )
  message.add(InfoDestinationSubmessage::new(prefix).to_submessage())
  assert_eq(message.destination_guid_prefix(), Ok(Some(prefix)))
  assert_eq(
    Message::new(Header::new(prefix, VendorId::new(1, 15))).destination_guid_prefix(),
    Ok(None),
  )
}

///|
test "RTPS message prepends INFO_DST before existing submessages" {
  let source = GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]).unwrap()
  let destination = GuidPrefix::from_array([
    11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
  ]).unwrap()
  let message = Message::new(Header::new(source, VendorId::new(1, 15)))
  message.add(
    DataSubmessage::new(
      EntityId::unknown(),
      EntityId::new(b"pub", 0xC2).unwrap(),
      1L,
      b"payload",
    ).to_submessage(),
  )
  let directed = message.with_destination_guid_prefix(destination)
  assert_eq(directed.submessages().length(), 2)
  assert_eq(directed.destination_guid_prefix(), Ok(Some(destination)))
  assert_eq(directed.submessages()[1].id(), Data)
}
