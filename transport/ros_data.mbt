///|
/// A ROS topic publisher backed by a discovered best-effort RTPS subscription.
///
/// The payload is already serialized with the message type's CDR codec. This
/// keeps the transport layer independent from generated ROS message types.
pub struct RosPublisher {
  topic : @ros.RosTopic
  writer : DataWriter
}

///|
/// Create a publisher for a discovered subscription with a matching topic.
pub fn RosPublisher::new_for_subscription(
  topic : @ros.RosTopic,
  socket : Udp,
  guid_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  writer_id : @rtps.EntityId,
  subscription : @rtps.SedpEndpointData,
  first_sequence_number : Int64,
) -> Result[RosPublisher, String] {
  if subscription.topic_name() != topic.dds_name() ||
    subscription.type_name() != topic.dds_type_name() {
    return Err("the discovered subscription does not match the ROS topic")
  }
  let qos = match subscription.qos() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if qos.reliability() != @rtps.RELIABILITY_BEST_EFFORT {
    return Err("the discovered subscription is not best effort")
  }
  let writer = match
    DataWriter::new_for_subscription(
      socket, guid_prefix, vendor_id, writer_id, subscription, first_sequence_number,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ topic, writer, })
}

///|
/// Return the ROS topic represented by this publisher.
pub fn RosPublisher::topic(self : RosPublisher) -> @ros.RosTopic {
  self.topic
}

///|
/// Return the next RTPS sequence number that will be published.
pub fn RosPublisher::next_sequence_number(self : RosPublisher) -> Int64 {
  self.writer.next_sequence_number()
}

///|
/// Publish one CDR-serialized ROS message.
pub async fn RosPublisher::publish(
  self : RosPublisher,
  serialized_payload : Bytes,
) -> Result[Unit, String] {
  self.writer.write(serialized_payload)
}

///|
/// Close the publisher's underlying UDP socket.
pub fn RosPublisher::close(self : RosPublisher) -> Unit {
  self.writer.close()
}

///|
/// A ROS topic subscription backed by a discovered best-effort RTPS publication.
pub struct RosSubscription {
  topic : @ros.RosTopic
  reader : DataReader
}

///|
/// Create a subscription for a discovered publication with a matching topic.
pub fn RosSubscription::new_for_publication(
  topic : @ros.RosTopic,
  socket : Udp,
  reader_id : @rtps.EntityId,
  publication : @rtps.SedpEndpointData,
) -> Result[RosSubscription, String] {
  ros_subscription_for_publication(
    topic, socket, None, reader_id, publication,
  )
}

///|
/// Create a best-effort subscription that filters INFO_DST for its participant.
pub fn RosSubscription::new_for_publication_with_prefix(
  topic : @ros.RosTopic,
  socket : Udp,
  participant_prefix : @rtps.GuidPrefix,
  reader_id : @rtps.EntityId,
  publication : @rtps.SedpEndpointData,
) -> Result[RosSubscription, String] {
  ros_subscription_for_publication(
    topic, socket, Some(participant_prefix), reader_id, publication,
  )
}

///|
fn ros_subscription_for_publication(
  topic : @ros.RosTopic,
  socket : Udp,
  participant_prefix : @rtps.GuidPrefix?,
  reader_id : @rtps.EntityId,
  publication : @rtps.SedpEndpointData,
) -> Result[RosSubscription, String] {
  if publication.topic_name() != topic.dds_name() ||
    publication.type_name() != topic.dds_type_name() {
    return Err("the discovered publication does not match the ROS topic")
  }
  let reader = match (match participant_prefix {
    Some(prefix) =>
      DataReader::new_for_publication_with_prefix(
        socket, prefix, reader_id, publication,
      )
    None => DataReader::new_for_publication(socket, reader_id, publication)
  }) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ topic, reader, })
}

///|
/// Return the ROS topic represented by this subscription.
pub fn RosSubscription::topic(self : RosSubscription) -> @ros.RosTopic {
  self.topic
}

///|
/// Receive one CDR-serialized ROS message and its source address.
pub async fn RosSubscription::receive(
  self : RosSubscription,
) -> Result[(Bytes, @socket.Addr), String] {
  let (data, source) = match self.reader.receive() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok((data.serialized_payload(), source))
}

///|
/// Close the subscription's underlying UDP socket.
pub fn RosSubscription::close(self : RosSubscription) -> Unit {
  self.reader.close()
}
