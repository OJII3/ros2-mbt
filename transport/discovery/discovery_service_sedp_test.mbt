///|
async test "discovery service announces SEDP endpoints to a participant" {
  let local_prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let remote_prefix = match
    @rtps.GuidPrefix::from_array([11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let participant_id = match
    @rtps.EntityId::new(b"abc", @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let local_participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(local_prefix, participant_id),
    @rtps.VendorId::new(1, 15),
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER,
  )
  let remote_participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(remote_prefix, participant_id),
    @rtps.VendorId::new(1, 15),
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PUBLICATIONS_DETECTOR,
  )
  let receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let locator = match
    @rtps.Locator::udp_v4(
      b"\x7F\x00\x00\x01",
      receiver.local_addr().port().reinterpret_as_uint(),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  remote_participant.add_metatraffic_unicast(locator)
  let sender = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let reader_id = match
    @rtps.EntityId::new(
      b"\x00\x01\x00",
      @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match
    @rtps.EntityId::new(
      b"\x00\x01\x00",
      @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let session = match
    DiscoverySession::new(
      sender,
      local_participant,
      reader_id,
      writer_id,
      receiver.local_addr(),
      1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let service = DiscoveryService::new(session)
  let endpoint_id = match @rtps.EntityId::new(b"def", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let endpoint = match
    @rtps.SedpEndpointData::new(
      Publication,
      @rtps.Guid::new(local_prefix, endpoint_id),
      "rt/chatter",
      "std_msgs::msg::dds_::String_",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let reliable_writer = match
    service.new_reliable_sedp_writer(endpoint, remote_participant, 1L) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match reliable_writer.announce_once() {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (decoded, source) = match receiver.receive_sedp(Publication) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.topic_name(), "rt/chatter")
  assert_eq(decoded.type_name(), "std_msgs::msg::dds_::String_")
  assert_eq(source.ip(), 0x7F000001U)
  let (heartbeat, _) = match receiver.receive_heartbeat() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(heartbeat.last_sequence_number(), 1L)
  let acknack = match
    @rtps.AckNackSubmessage::new(
      @rtps.SedpEndpointKind::Publication.builtin_reader_id(),
      @rtps.SedpEndpointKind::Publication.builtin_writer_id(),
      1L,
      1U,
      [0U],
      1U,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match
    receiver.send_acknack(
      acknack,
      remote_prefix,
      @rtps.VendorId::new(1, 15),
      sender.local_addr(),
    ) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (decoded_acknack, _) = match reliable_writer.receive_acknack() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded_acknack.count(), 1U)
  assert_eq(reliable_writer.history_length(), 1)
  assert_eq(service.next_sedp_sequence_number(Publication), 1L)
  assert_eq(service.next_sedp_sequence_number(Subscription), 1L)
  service.close()
  receiver.close()
}

///|
async test "discovery service announces SEDP to all discovered participants" {
  let local_prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let remote_prefix = match
    @rtps.GuidPrefix::from_array([11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let second_remote_prefix = match
    @rtps.GuidPrefix::from_array([
      10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120,
    ]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let participant_id = match
    @rtps.EntityId::new(b"abc", @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let local_participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(local_prefix, participant_id),
    @rtps.VendorId::new(1, 15),
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER,
  )
  let remote_participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(remote_prefix, participant_id),
    @rtps.VendorId::new(1, 15),
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PUBLICATIONS_DETECTOR,
  )
  let second_remote_participant = @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(second_remote_prefix, participant_id),
    @rtps.VendorId::new(1, 15),
    0,
    60,
    0,
    @rtps.BUILTIN_ENDPOINT_PUBLICATIONS_DETECTOR,
  )
  let service_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let remote_receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let second_remote_receiver = @wire.Udp::bind(
    @socket.Addr::new(0x7F000001U, 0),
  )
  let remote_locator = match
    @rtps.Locator::udp_v4(
      b"\x7F\x00\x00\x01",
      remote_receiver.local_addr().port().reinterpret_as_uint(),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  remote_participant.add_metatraffic_unicast(remote_locator)
  let second_remote_locator = match
    @rtps.Locator::udp_v4(
      b"\x7F\x00\x00\x01",
      second_remote_receiver.local_addr().port().reinterpret_as_uint(),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  second_remote_participant.add_metatraffic_unicast(second_remote_locator)
  let reader_id = match
    @rtps.EntityId::new(
      b"\x00\x01\x00",
      @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_id = match
    @rtps.EntityId::new(
      b"\x00\x01\x00",
      @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let session = match
    DiscoverySession::new(
      service_socket,
      local_participant,
      reader_id,
      writer_id,
      remote_receiver.local_addr(),
      1L,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let service = DiscoveryService::new(session)
  service.graph().ingest(Participant(remote_participant))
  service.graph().ingest(Participant(second_remote_participant))
  let endpoint_id = match @rtps.EntityId::new(b"def", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let endpoint = match
    @rtps.SedpEndpointData::new(
      Publication,
      @rtps.Guid::new(local_prefix, endpoint_id),
      "rt/chatter",
      "std_msgs::msg::dds_::String_",
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  match service.announce_sedp_n(endpoint, 1, 2) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (decoded_data, _) = match remote_receiver.receive_data() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let decoded = match
    @rtps.SedpEndpointData::from_data_submessage(Publication, decoded_data) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (first_heartbeat, _) = match remote_receiver.receive_heartbeat() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (second_remote_decoded_data, _) = match
    second_remote_receiver.receive_data() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let second_remote_decoded = match
    @rtps.SedpEndpointData::from_data_submessage(
      Publication,
      second_remote_decoded_data,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (second_remote_first_heartbeat, _) = match
    second_remote_receiver.receive_heartbeat() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (second_data, _) = match remote_receiver.receive_data() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let second = match
    @rtps.SedpEndpointData::from_data_submessage(Publication, second_data) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (second_heartbeat, _) = match remote_receiver.receive_heartbeat() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (second_remote_second_data, _) = match
    second_remote_receiver.receive_data() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let second_remote_second = match
    @rtps.SedpEndpointData::from_data_submessage(
      Publication,
      second_remote_second_data,
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (second_remote_second_heartbeat, _) = match
    second_remote_receiver.receive_heartbeat() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.topic_name(), "rt/chatter")
  assert_eq(second.topic_name(), "rt/chatter")
  assert_eq(second_remote_decoded.topic_name(), "rt/chatter")
  assert_eq(second_remote_second.topic_name(), "rt/chatter")
  assert_eq(decoded_data.writer_sequence_number(), 1L)
  assert_eq(second_data.writer_sequence_number(), 2L)
  assert_eq(second_remote_decoded_data.writer_sequence_number(), 1L)
  assert_eq(second_remote_second_data.writer_sequence_number(), 2L)
  assert_eq(first_heartbeat.count(), 1U)
  assert_eq(second_heartbeat.count(), 2U)
  assert_eq(second_remote_first_heartbeat.count(), 1U)
  assert_eq(second_remote_second_heartbeat.count(), 2U)
  assert_eq(service.next_sedp_sequence_number(Publication), 3L)
  match service.dispose_sedp_to_all(endpoint) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (disposed_data, _) = match remote_receiver.receive_data() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(disposed_data.writer_sequence_number(), 3L)
  assert_eq(
    disposed_data.serialized_payload(),
    endpoint.endpoint_guid().to_bytes(),
  )
  assert_eq(
    disposed_data.status_info(),
    Ok(Some(@rtps.STATUS_INFO_DISPOSED | @rtps.STATUS_INFO_UNREGISTERED)),
  )
  let (dispose_heartbeat, _) = match remote_receiver.receive_heartbeat() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let (second_disposed_data, _) = match second_remote_receiver.receive_data() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(second_disposed_data.writer_sequence_number(), 3L)
  let (second_dispose_heartbeat, _) = match
    second_remote_receiver.receive_heartbeat() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(dispose_heartbeat.count(), 3U)
  assert_eq(second_dispose_heartbeat.count(), 3U)
  assert_eq(service.next_sedp_sequence_number(Publication), 4L)
  service.close()
  remote_receiver.close()
  second_remote_receiver.close()
}

///|
