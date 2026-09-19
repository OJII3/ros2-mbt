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

///|
async test "two discovery services establish a ROS String data path" {
  let publisher_prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let subscriber_prefix = match
    @rtps.GuidPrefix::from_array([11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let participant_id = match @rtps.EntityId::new(b"prt", 0xC1) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let spdp_reader = match
    @rtps.EntityId::new(
      b"\x00\x01\x00",
      @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let spdp_writer = match
    @rtps.EntityId::new(
      b"\x00\x01\x00",
      @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let publisher_spdp = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let subscriber_spdp = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let publisher_participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(publisher_prefix, participant_id),
    @rtps.VendorId::new(1, 15),
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR |
    @rtps.BUILTIN_ENDPOINT_PUBLICATIONS_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PUBLICATIONS_DETECTOR |
    @rtps.BUILTIN_ENDPOINT_SUBSCRIPTIONS_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_SUBSCRIPTIONS_DETECTOR,
  )
  let subscriber_participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(subscriber_prefix, participant_id),
    @rtps.VendorId::new(1, 15),
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR |
    @rtps.BUILTIN_ENDPOINT_PUBLICATIONS_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_PUBLICATIONS_DETECTOR |
    @rtps.BUILTIN_ENDPOINT_SUBSCRIPTIONS_ANNOUNCER |
    @rtps.BUILTIN_ENDPOINT_SUBSCRIPTIONS_DETECTOR,
  )
  let publisher_locator = match
    @rtps.Locator::udp_v4(
      b"\x7F\x00\x00\x01",
      publisher_spdp.local_addr().port().reinterpret_as_uint(),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let subscriber_locator = match
    @rtps.Locator::udp_v4(
      b"\x7F\x00\x00\x01",
      subscriber_spdp.local_addr().port().reinterpret_as_uint(),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  publisher_participant.add_metatraffic_unicast(publisher_locator)
  subscriber_participant.add_metatraffic_unicast(subscriber_locator)
  let publisher_session = match
    DiscoverySession::new(
      publisher_spdp,
      publisher_participant,
      spdp_reader,
      spdp_writer,
      subscriber_spdp.local_addr(),
      1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let subscriber_session = match
    DiscoverySession::new(
      subscriber_spdp,
      subscriber_participant,
      spdp_reader,
      spdp_writer,
      publisher_spdp.local_addr(),
      1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let publisher_service = DiscoveryService::new(publisher_session)
  let subscriber_service = DiscoveryService::new(subscriber_session)
  match publisher_service.announce_once() {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match subscriber_service.announce_once() {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match publisher_service.receive_once() {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match subscriber_service.receive_once() {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let topic = match
    @ros.RosTopic::new("/chatter", "std_msgs", "msg", "String") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let publisher_id = match @rtps.EntityId::new(b"pub", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let subscriber_id = match @rtps.EntityId::new(b"sub", 0xC7) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let publication = match
    topic.to_sedp(
      @rtps.SedpEndpointKind::Publication,
      @rtps.Guid::new(publisher_prefix, publisher_id),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let subscription = match
    topic.to_sedp(
      @rtps.SedpEndpointKind::Subscription,
      @rtps.Guid::new(subscriber_prefix, subscriber_id),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let publisher_user = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let subscriber_user = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let publisher_user_locator = match
    @rtps.Locator::udp_v4(
      b"\x7F\x00\x00\x01",
      publisher_user.local_addr().port().reinterpret_as_uint(),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let subscriber_user_locator = match
    @rtps.Locator::udp_v4(
      b"\x7F\x00\x00\x01",
      subscriber_user.local_addr().port().reinterpret_as_uint(),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  publication.add_unicast_locator(publisher_user_locator)
  subscription.add_unicast_locator(subscriber_user_locator)
  match
    publisher_service.announce_sedp_once(publication, subscriber_participant) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match
    subscriber_service.announce_sedp_once(subscription, publisher_participant) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match subscriber_service.receive_once() {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  match publisher_service.receive_once() {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let writer = match
    DataWriter::new_for_subscription(
      publisher_user,
      publisher_prefix,
      @rtps.VendorId::new(1, 15),
      publisher_id,
      publisher_service.graph().subscriptions()[0],
      1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let reader = match
    DataReader::new_for_publication(
      subscriber_user,
      subscriber_id,
      subscriber_service.graph().publications()[0],
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match
    writer.write(@ros.StringMessage::new("discovered hello").to_cdr_bytes()) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (data, source) = match reader.receive() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let message = match
    @ros.StringMessage::from_cdr_bytes(data.serialized_payload()) {
    Ok(value) => value
    Err(error) => fail(error)
  }
  assert_eq(message.data(), "discovered hello")
  assert_eq(source.ip(), 0x7F000001U)
  publisher_service.close()
  subscriber_service.close()
  writer.close()
  reader.close()
}
