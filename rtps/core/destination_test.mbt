///|
test "RTPS INFO_DST round trips a GUID prefix" {
  let destination = @core.InfoDestinationSubmessage::new(
    @core.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]).unwrap(),
  )
  let encoded = destination.to_submessage().to_bytes().unwrap()
  assert_eq(
    encoded, b"\x0E\x01\x0C\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B",
  )
  let decoded = @core.InfoDestinationSubmessage::from_submessage(
    @core.Submessage::from_bytes(encoded).unwrap().0,
  ).unwrap()
  assert_eq(decoded, destination)
}

///|
test "RTPS INFO_DST rejects non-prefix bodies" {
  assert_true(
    @core.InfoDestinationSubmessage::from_submessage(
      @core.Submessage::new(InfoDestination, 0x01, b"short"),
    )
    is Err(_),
  )
}

///|
test "RTPS message exposes its optional INFO_DST prefix" {
  let prefix = @core.GuidPrefix::from_array([
    11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
  ]).unwrap()
  let message = @core.Message::new(
    @core.Header::new(
      @core.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]).unwrap(),
      @core.VendorId::new(1, 15),
    ),
  )
  message.add(@core.InfoDestinationSubmessage::new(prefix).to_submessage())
  assert_eq(message.destination_guid_prefix(), Ok(Some(prefix)))
  assert_eq(
    @core.Message::new(@core.Header::new(prefix, @core.VendorId::new(1, 15))).destination_guid_prefix(),
    Ok(None),
  )
}

///|
test "RTPS message prepends INFO_DST before existing submessages" {
  let source = @core.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let destination = @core.GuidPrefix::from_array([
    11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
  ]).unwrap()
  let message = @core.Message::new(
    @core.Header::new(source, @core.VendorId::new(1, 15)),
  )
  message.add(
    @core.DataSubmessage::new(
      @core.EntityId::unknown(),
      @core.EntityId::new(b"pub", 0xC2).unwrap(),
      1L,
      b"payload",
    ).to_submessage(),
  )
  let directed = message.with_destination_guid_prefix(destination)
  assert_eq(directed.submessages().length(), 2)
  assert_eq(directed.destination_guid_prefix(), Ok(Some(destination)))
  assert_eq(directed.submessages()[1].id(), Data)
}
