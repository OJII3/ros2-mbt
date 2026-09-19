///|
async test "ROS String topic flows through discovered best-effort endpoints" {
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match @rtps.EntityId::new(b"pub", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let reader_id = match @rtps.EntityId::new(b"sub", 0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let topic = match
    @ros.RosTopic::new("/chatter", "std_msgs", "msg", "String") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let publication = match
    topic.to_sedp(
      @rtps.SedpEndpointKind::Publication,
      @rtps.Guid::new(prefix, writer_id),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let subscription = match
    topic.to_sedp(
      @rtps.SedpEndpointKind::Subscription,
      @rtps.Guid::new(prefix, reader_id),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let receiver_address = receiver.local_addr()
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender_address = sender.local_addr()
  let receiver_locator = match
    @rtps.Locator::udp_v4(
      b"\x7F\x00\x00\x01",
      receiver_address.port().reinterpret_as_uint(),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let sender_locator = match
    @rtps.Locator::udp_v4(
      b"\x7F\x00\x00\x01",
      sender_address.port().reinterpret_as_uint(),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  subscription.add_unicast_locator(receiver_locator)
  publication.add_unicast_locator(sender_locator)
  let writer = match
    DataWriter::new_for_subscription(
      sender,
      prefix,
      @rtps.VendorId::new(1, 15),
      writer_id,
      subscription,
      1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let reader = match
    DataReader::new_for_publication(receiver, reader_id, publication) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let message = @ros.StringMessage::new("hello from MoonBit")
  match writer.write(message.to_cdr_bytes()) {
    Ok(_) => ()
    Err(error) => fail(error)
  }
  let (data, source) = match reader.receive() {
    Ok(value) => value
    Err(error) => fail(error)
  }
  let decoded = match
    @ros.StringMessage::from_cdr_bytes(data.serialized_payload()) {
    Ok(value) => value
    Err(error) => fail(error)
  }
  assert_eq(decoded.data(), "hello from MoonBit")
  assert_eq(source.ip(), 0x7F000001U)
  writer.close()
  reader.close()
}
