///|
async test "ROS publisher and subscription validate the topic identity" {
  let topic = match
    @ros_types.RosTopic::new("/chatter", "std_msgs", "msg", "String") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let best_effort_qos = @rtps.SedpQos::new(
    @rtps.RELIABILITY_BEST_EFFORT,
    @rtps.DURABILITY_VOLATILE,
    @rtps.HISTORY_KEEP_LAST,
    1,
  )
  let other_topic = match
    @ros_types.RosTopic::new("/other", "std_msgs", "msg", "String") {
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
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let receiver_locator = match receiver.local_unicast_locator() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let sender_locator = match sender.local_unicast_locator() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let publication = match
    topic.to_sedp_with_qos(
      Publication,
      @rtps.Guid::new(prefix, writer_id),
      best_effort_qos,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  publication.add_unicast_locator(sender_locator)
  let subscription = match
    topic.to_sedp_with_qos(
      Subscription,
      @rtps.Guid::new(prefix, reader_id),
      best_effort_qos,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  subscription.add_unicast_locator(receiver_locator)
  assert_true(
    @ros.RosPublisher::new_for_subscription(
      other_topic,
      sender,
      prefix,
      @rtps.VendorId::new(1, 15),
      writer_id,
      subscription,
      1L,
    )
    is Err(_),
  )
  let reliable_subscription = match
    topic.to_sedp_with_qos(
      Subscription,
      @rtps.Guid::new(prefix, reader_id),
      @rtps.SedpQos::new(
        @rtps.RELIABILITY_RELIABLE,
        @rtps.DURABILITY_VOLATILE,
        @rtps.HISTORY_KEEP_LAST,
        1,
      ),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  reliable_subscription.add_unicast_locator(receiver_locator)
  assert_true(
    @ros.RosPublisher::new_for_subscription(
      topic,
      sender,
      prefix,
      @rtps.VendorId::new(1, 15),
      writer_id,
      reliable_subscription,
      1L,
    )
    is Err(_),
  )
  sender.close()
  receiver.close()
}

///|
async test "ROS publisher and subscription exchange a CDR payload" {
  let topic = match
    @ros_types.RosTopic::new("/chatter", "std_msgs", "msg", "String") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let best_effort_qos = @rtps.SedpQos::new(
    @rtps.RELIABILITY_BEST_EFFORT,
    @rtps.DURABILITY_VOLATILE,
    @rtps.HISTORY_KEEP_LAST,
    1,
  )
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
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let receiver_locator = match receiver.local_unicast_locator() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let sender_locator = match sender.local_unicast_locator() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let publication = match
    topic.to_sedp_with_qos(
      Publication,
      @rtps.Guid::new(prefix, writer_id),
      best_effort_qos,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  publication.add_unicast_locator(sender_locator)
  let subscription = match
    topic.to_sedp_with_qos(
      Subscription,
      @rtps.Guid::new(prefix, reader_id),
      best_effort_qos,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  subscription.add_unicast_locator(receiver_locator)
  let publisher = match
    @ros.RosPublisher::new_for_subscription(
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
    @ros.RosSubscription::new_for_publication(
      topic, receiver, reader_id, publication,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let message = @ros_types.StringMessage::new("hello from the ROS facade")
  match publisher.publish(message.to_cdr_bytes()) {
    Ok(_) => ()
    Err(error) => fail(error)
  }
  let (payload, source) = match subscriber.receive() {
    Ok(value) => value
    Err(error) => fail(error)
  }
  let decoded = match @ros_types.StringMessage::from_cdr_bytes(payload) {
    Ok(value) => value
    Err(error) => fail(error)
  }
  assert_eq(decoded.data(), message.data())
  assert_eq(publisher.next_sequence_number(), 2L)
  assert_eq(source.ip(), 0x7F000001U)
  publisher.close()
  subscriber.close()
}
