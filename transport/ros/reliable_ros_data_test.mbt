///|
async test "reliable ROS publisher and subscription exchange a CDR payload" {
  let topic = match
    @ros_types.RosTopic::new("/chatter", "std_msgs", "msg", "String") {
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
  let receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  defer receiver.close()
  let second_receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  defer second_receiver.close()
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  defer sender.close()
  let receiver_locator = match receiver.local_unicast_locator() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let second_receiver_locator = match second_receiver.local_unicast_locator() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let sender_locator = match sender.local_unicast_locator() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let publication = match
    topic.to_sedp(Publication, @rtps.Guid::new(prefix, writer_id)) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  publication.add_unicast_locator(sender_locator)
  let subscription = match
    topic.to_sedp(Subscription, @rtps.Guid::new(prefix, reader_id)) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  subscription.add_unicast_locator(receiver_locator)
  let second_reader_id = match @rtps.EntityId::new(b"sub", 0xC8) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let second_subscription = match
    topic.to_sedp(Subscription, @rtps.Guid::new(prefix, second_reader_id)) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  second_subscription.add_unicast_locator(second_receiver_locator)
  let publisher = match
    @ros.ReliableRosPublisher::new_for_subscription(
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
  match publisher.add_subscription(second_subscription) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let subscriber = match
    @ros.ReliableRosSubscription::new_for_publication(
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
  let second_subscriber = match
    @ros.ReliableRosSubscription::new_for_publication(
      topic,
      second_receiver,
      prefix,
      @rtps.VendorId::new(1, 15),
      second_reader_id,
      publication,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let message = @ros_types.StringMessage::new("reliable hello from ROS")
  match publisher.publish(message.to_cdr_bytes()) {
    Ok(_) => ()
    Err(error) => fail(error)
  }
  match publisher.send_heartbeat() {
    Ok(_) => ()
    Err(error) => fail(error)
  }
  let (payload, source) = match test_receive(() => subscriber.receive()) {
    Ok(value) => value
    Err(error) => fail(error)
  }
  let (second_payload, second_source) = match
    test_receive(() => second_subscriber.receive()) {
    Ok(value) => value
    Err(error) => fail(error)
  }
  let (heartbeat, _) = match
    test_receive(() => subscriber.receive_heartbeat()) {
    Ok(value) => value
    Err(error) => fail(error)
  }
  let (second_heartbeat, _) = match
    test_receive(() => second_subscriber.receive_heartbeat()) {
    Ok(value) => value
    Err(error) => fail(error)
  }
  let (acknack, _) = match test_receive(() => publisher.receive_acknack()) {
    Ok(value) => value
    Err(error) => fail(error)
  }
  let (second_acknack, _) = match
    test_receive(() => publisher.receive_acknack()) {
    Ok(value) => value
    Err(error) => fail(error)
  }
  let decoded = match @ros_types.StringMessage::from_cdr_bytes(payload) {
    Ok(value) => value
    Err(error) => fail(error)
  }
  assert_eq(decoded.data(), message.data())
  let second_decoded = match
    @ros_types.StringMessage::from_cdr_bytes(second_payload) {
    Ok(value) => value
    Err(error) => fail(error)
  }
  assert_eq(second_decoded.data(), message.data())
  assert_eq(heartbeat.last_sequence_number(), 1L)
  assert_eq(second_heartbeat.last_sequence_number(), 1L)
  assert_eq(acknack.bitmap_base(), 2L)
  assert_eq(acknack.num_bits(), 0U)
  assert_eq(acknack.bitmap(), [])
  assert_eq(second_acknack.bitmap_base(), 2L)
  assert_eq(second_acknack.num_bits(), 0U)
  assert_eq(second_acknack.bitmap(), [])
  assert_eq(publisher.next_sequence_number(), 2L)
  assert_eq(publisher.history_length(), 0)
  assert_eq(subscriber.sample_count(), 1)
  assert_eq(source.ip(), 0x7F000001U)
  assert_eq(second_source.ip(), 0x7F000001U)
  publisher.close()
  subscriber.close()
  second_subscriber.close()
}
