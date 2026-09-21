///|
/// A reliable publisher for `rmw_dds_common/msg/ParticipantEntitiesInfo`.
pub struct ReliableRosDiscoveryPublisher {
  writer : @wire.ReliableDataWriter
}

///|
/// Create a graph-discovery publisher for a matching discovered subscription.
pub fn ReliableRosDiscoveryPublisher::new_for_subscription(
  socket : @wire.Udp,
  guid_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  writer_id : @rtps.EntityId,
  subscription : @rtps.SedpEndpointData,
  first_sequence_number : Int64,
) -> Result[ReliableRosDiscoveryPublisher, String] {
  match
    @ros_types.validate_ros_discovery_info_endpoint(
      subscription,
      @rtps.SedpEndpointKind::Subscription,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let writer = match
    @wire.ReliableDataWriter::new_for_subscription(
      socket, guid_prefix, vendor_id, writer_id, subscription, first_sequence_number,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ writer, })
}

///|
/// Return the next RTPS sequence number that will be published.
pub fn ReliableRosDiscoveryPublisher::next_sequence_number(
  self : ReliableRosDiscoveryPublisher,
) -> Int64 {
  self.writer.next_sequence_number()
}

///|
/// Return the number of graph samples retained for retransmission.
pub fn ReliableRosDiscoveryPublisher::history_length(
  self : ReliableRosDiscoveryPublisher,
) -> Int {
  self.writer.history_length()
}

///|
/// Publish one graph-discovery sample and retain it for retransmission.
pub async fn ReliableRosDiscoveryPublisher::publish(
  self : ReliableRosDiscoveryPublisher,
  info : @ros_types.ParticipantEntitiesInfo,
) -> Result[Unit, String] {
  self.writer.write(info.to_cdr_bytes())
}

///|
/// Publish one graph-discovery sample and announce it with a HEARTBEAT.
pub async fn ReliableRosDiscoveryPublisher::announce_once(
  self : ReliableRosDiscoveryPublisher,
  info : @ros_types.ParticipantEntitiesInfo,
) -> Result[Unit, String] {
  match self.publish(info) {
    Ok(_) => self.writer.send_heartbeat()
    Err(message) => Err(message)
  }
}

///|
/// Receive a matching ACKNACK and retransmit requested graph samples.
pub async fn ReliableRosDiscoveryPublisher::receive_acknack(
  self : ReliableRosDiscoveryPublisher,
) -> Result[(@rtps.AckNackSubmessage, @socket.Addr), String] {
  self.writer.receive_acknack()
}

///|
/// Receive a matching NACK_FRAG and retransmit requested graph fragments.
pub async fn ReliableRosDiscoveryPublisher::receive_nackfrag(
  self : ReliableRosDiscoveryPublisher,
) -> Result[(@rtps.NackFragSubmessage, @socket.Addr), String] {
  self.writer.receive_nackfrag()
}

///|
/// Receive either ACKNACK or NACK_FRAG and retransmit requested graph data.
pub async fn ReliableRosDiscoveryPublisher::receive_control(
  self : ReliableRosDiscoveryPublisher,
) -> Result[Unit, String] {
  self.writer.receive_control()
}

///|
/// Apply an ACKNACK directly and retransmit requested graph samples.
pub async fn ReliableRosDiscoveryPublisher::handle_acknack(
  self : ReliableRosDiscoveryPublisher,
  acknack : @rtps.AckNackSubmessage,
) -> Result[Unit, String] {
  self.writer.handle_acknack(acknack)
}

///|
/// Close the publisher's underlying UDP socket.
pub fn ReliableRosDiscoveryPublisher::close(
  self : ReliableRosDiscoveryPublisher,
) -> Unit {
  self.writer.close()
}

///|
/// A reliable subscription for `rmw_dds_common/msg/ParticipantEntitiesInfo`.
pub struct ReliableRosDiscoverySubscription {
  reader : @wire.ReliableDataReaderSession
}

///|
/// Create a graph-discovery subscription for a matching publication.
pub fn ReliableRosDiscoverySubscription::new_for_publication(
  socket : @wire.Udp,
  guid_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  reader_id : @rtps.EntityId,
  publication : @rtps.SedpEndpointData,
) -> Result[ReliableRosDiscoverySubscription, String] {
  match
    @ros_types.validate_ros_discovery_info_endpoint(
      publication,
      @rtps.SedpEndpointKind::Publication,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let reader = match
    @wire.ReliableDataReaderSession::new_for_publication(
      socket, guid_prefix, vendor_id, reader_id, publication,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ reader, })
}

///|
/// Receive and decode one graph-discovery sample.
pub async fn ReliableRosDiscoverySubscription::receive(
  self : ReliableRosDiscoverySubscription,
) -> Result[(@ros_types.ParticipantEntitiesInfo, @socket.Addr), String] {
  let (data, source) = match self.reader.receive_data() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let info = match
    @ros_types.ParticipantEntitiesInfo::from_cdr_bytes(
      data.serialized_payload(),
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok((info, source))
}

///|
/// Receive a HEARTBEAT, acknowledge it, and return it to the caller.
pub async fn ReliableRosDiscoverySubscription::receive_heartbeat(
  self : ReliableRosDiscoverySubscription,
) -> Result[(@rtps.HeartbeatSubmessage, @socket.Addr), String] {
  self.reader.receive_heartbeat()
}

///|
/// Return the number of graph samples accepted by the subscription.
pub fn ReliableRosDiscoverySubscription::sample_count(
  self : ReliableRosDiscoverySubscription,
) -> Int {
  self.reader.sample_count()
}

///|
/// Close the subscription's underlying UDP socket.
pub fn ReliableRosDiscoverySubscription::close(
  self : ReliableRosDiscoverySubscription,
) -> Unit {
  self.reader.close()
}
