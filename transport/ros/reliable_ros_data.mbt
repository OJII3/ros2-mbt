///|
/// A reliable ROS topic publisher backed by a discovered subscription.
pub struct ReliableRosPublisher {
  topic : @ros_types.RosTopic
  writer : @wire.ReliableDataWriter
}

///|
/// Create a reliable publisher for a matching discovered subscription.
pub fn ReliableRosPublisher::new_for_subscription(
  topic : @ros_types.RosTopic,
  socket : @wire.Udp,
  guid_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  writer_id : @rtps.EntityId,
  subscription : @rtps.SedpEndpointData,
  first_sequence_number : Int64,
) -> Result[ReliableRosPublisher, String] {
  if subscription.topic_name() != topic.dds_name() ||
    subscription.type_name() != topic.dds_type_name() {
    return Err("the discovered subscription does not match the ROS topic")
  }
  let qos = match subscription.qos() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if qos.reliability() != @rtps.RELIABILITY_RELIABLE {
    return Err("the discovered subscription is not reliable")
  }
  let writer = match
    @wire.ReliableDataWriter::new_for_subscription(
      socket, guid_prefix, vendor_id, writer_id, subscription, first_sequence_number,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ topic, writer, })
}

///|
/// Return the ROS topic represented by this publisher.
pub fn ReliableRosPublisher::topic(
  self : ReliableRosPublisher,
) -> @ros_types.RosTopic {
  self.topic
}

///|
/// Return the next RTPS sequence number that will be published.
pub fn ReliableRosPublisher::next_sequence_number(
  self : ReliableRosPublisher,
) -> Int64 {
  self.writer.next_sequence_number()
}

///|
/// Return the number of samples retained for retransmission.
pub fn ReliableRosPublisher::history_length(self : ReliableRosPublisher) -> Int {
  self.writer.history_length()
}

///|
/// Publish one CDR-serialized ROS message and retain it for retransmission.
pub async fn ReliableRosPublisher::publish(
  self : ReliableRosPublisher,
  serialized_payload : Bytes,
) -> Result[Unit, String] {
  self.writer.write(serialized_payload)
}

///|
/// Announce the retained samples to the remote reliable reader.
pub async fn ReliableRosPublisher::send_heartbeat(
  self : ReliableRosPublisher,
) -> Result[Unit, String] {
  self.writer.send_heartbeat()
}

///|
/// Receive a matching ACKNACK and retransmit requested samples.
pub async fn ReliableRosPublisher::receive_acknack(
  self : ReliableRosPublisher,
) -> Result[(@rtps.AckNackSubmessage, @socket.Addr), String] {
  self.writer.receive_acknack()
}

///|
/// Apply an ACKNACK directly and retransmit requested samples.
pub async fn ReliableRosPublisher::handle_acknack(
  self : ReliableRosPublisher,
  acknack : @rtps.AckNackSubmessage,
) -> Result[Unit, String] {
  self.writer.handle_acknack(acknack)
}

///|
/// Receive a matching NACK_FRAG and retransmit requested fragments.
pub async fn ReliableRosPublisher::receive_nackfrag(
  self : ReliableRosPublisher,
) -> Result[(@rtps.NackFragSubmessage, @socket.Addr), String] {
  self.writer.receive_nackfrag()
}

///|
/// Receive either ACKNACK or NACK_FRAG and retransmit the requested samples.
pub async fn ReliableRosPublisher::receive_control(
  self : ReliableRosPublisher,
) -> Result[Unit, String] {
  self.writer.receive_control()
}

///|
/// Apply a NACK_FRAG directly and retransmit requested fragments.
pub async fn ReliableRosPublisher::handle_nackfrag(
  self : ReliableRosPublisher,
  nackfrag : @rtps.NackFragSubmessage,
) -> Result[Unit, String] {
  self.writer.handle_nackfrag(nackfrag)
}

///|
/// Close the publisher's underlying UDP socket.
pub fn ReliableRosPublisher::close(self : ReliableRosPublisher) -> Unit {
  self.writer.close()
}

///|
/// A reliable ROS topic subscription backed by a discovered publication.
pub struct ReliableRosSubscription {
  topic : @ros_types.RosTopic
  reader : @wire.ReliableDataReaderSession
}

///|
/// Create a reliable subscription for a matching discovered publication.
pub fn ReliableRosSubscription::new_for_publication(
  topic : @ros_types.RosTopic,
  socket : @wire.Udp,
  guid_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  reader_id : @rtps.EntityId,
  publication : @rtps.SedpEndpointData,
) -> Result[ReliableRosSubscription, String] {
  if publication.topic_name() != topic.dds_name() ||
    publication.type_name() != topic.dds_type_name() {
    return Err("the discovered publication does not match the ROS topic")
  }
  let qos = match publication.qos() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if qos.reliability() != @rtps.RELIABILITY_RELIABLE {
    return Err("the discovered publication is not reliable")
  }
  let reader = match
    @wire.ReliableDataReaderSession::new_for_publication(
      socket, guid_prefix, vendor_id, reader_id, publication,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ topic, reader, })
}

///|
/// Return the ROS topic represented by this subscription.
pub fn ReliableRosSubscription::topic(
  self : ReliableRosSubscription,
) -> @ros_types.RosTopic {
  self.topic
}

///|
/// Receive one CDR-serialized ROS message and its source address.
pub async fn ReliableRosSubscription::receive(
  self : ReliableRosSubscription,
) -> Result[(Bytes, @socket.Addr), String] {
  let (data, source) = match self.reader.receive_data() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok((data.serialized_payload(), source))
}

///|
/// Receive a HEARTBEAT, acknowledge it, and return it to the caller.
pub async fn ReliableRosSubscription::receive_heartbeat(
  self : ReliableRosSubscription,
) -> Result[(@rtps.HeartbeatSubmessage, @socket.Addr), String] {
  self.reader.receive_heartbeat()
}

///|
/// Return the number of samples accepted by the subscription.
pub fn ReliableRosSubscription::sample_count(
  self : ReliableRosSubscription,
) -> Int {
  self.reader.sample_count()
}

///|
/// Close the subscription's underlying UDP socket.
pub fn ReliableRosSubscription::close(self : ReliableRosSubscription) -> Unit {
  self.reader.close()
}
