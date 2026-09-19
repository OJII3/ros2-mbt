///|
async test "reliable ROS publisher and subscription exchange a CDR payload" {
  let topic = match
    @ros.RosTopic::new("/chatter", "std_msgs", "msg", "String") {
    Ok(value) => value
    Err(message) => fail(message)
  }
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
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let receiver_locator = match receiver.local_unicast_locator() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let sender_locator = match sender.local_unicast_locator() {
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
  publication.add_unicast_locator(sender_locator)
  publication.add_parameter(@rtps.qos_reliability(2U, 0, 0))
  let subscription = match
    topic.to_sedp(
      @rtps.SedpEndpointKind::Subscription,
      @rtps.Guid::new(prefix, reader_id),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  subscription.add_unicast_locator(receiver_locator)
  subscription.add_parameter(@rtps.qos_reliability(2U, 0, 0))
  let publisher = match
    ReliableRosPublisher::new_for_subscription(
      topic,
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
  let subscriber = match
    ReliableRosSubscription::new_for_publication(
      topic,
      receiver,
      prefix,
      @rtps.VendorId::new(1, 15),
      reader_id,
      publication,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let message = @ros.StringMessage::new("reliable hello from ROS")
  match publisher.publish(message.to_cdr_bytes()) {
    Ok(_) => ()
    Err(error) => fail(error)
  }
  match publisher.send_heartbeat() {
    Ok(_) => ()
    Err(error) => fail(error)
  }
  let (payload, source) = match subscriber.receive() {
    Ok(value) => value
    Err(error) => fail(error)
  }
  let (heartbeat, _) = match subscriber.receive_heartbeat() {
    Ok(value) => value
    Err(error) => fail(error)
  }
  let (acknack, _) = match publisher.receive_acknack() {
    Ok(value) => value
    Err(error) => fail(error)
  }
  let decoded = match @ros.StringMessage::from_cdr_bytes(payload) {
    Ok(value) => value
    Err(error) => fail(error)
  }
  assert_eq(decoded.data(), message.data())
  assert_eq(heartbeat.last_sequence_number(), 1L)
  assert_eq(acknack.bitmap(), [0U])
  assert_eq(publisher.next_sequence_number(), 2L)
  assert_eq(publisher.history_length(), 1)
  assert_eq(subscriber.sample_count(), 1)
  assert_eq(source.ip(), 0x7F000001U)
  publisher.close()
  subscriber.close()
}
