///|
/// A ROS topic publisher backed by discovered best-effort RTPS subscriptions.
///
/// The payload is already serialized with the message type's CDR codec. This
/// keeps the transport layer independent from generated ROS message types.
pub struct RosPublisher {
  topic : @ros_types.RosTopic
  socket : @wire.Udp
  guid_prefix : @rtps.GuidPrefix
  vendor_id : @rtps.VendorId
  writer_id : @rtps.EntityId
  mut writers : Array[(@rtps.Guid, @wire.DataWriter)]
  mut next_sequence_number : Int64
}

///|
/// Create a publisher for a discovered subscription with a matching topic.
pub fn RosPublisher::new_for_subscription(
  topic : @ros_types.RosTopic,
  socket : @wire.Udp,
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
  if qos.durability() != @rtps.DURABILITY_VOLATILE {
    return Err("the discovered subscription has incompatible durability")
  }
  let writer = match
    @wire.DataWriter::new_for_subscription(
      socket, guid_prefix, vendor_id, writer_id, subscription, first_sequence_number,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({
    topic,
    socket,
    guid_prefix,
    vendor_id,
    writer_id,
    writers: [(subscription.endpoint_guid(), writer)],
    next_sequence_number: first_sequence_number,
  })
}

///|
/// Add a matching best-effort subscription to this topic publisher.
pub fn RosPublisher::add_subscription(
  self : RosPublisher,
  subscription : @rtps.SedpEndpointData,
) -> Result[Unit, String] {
  if subscription.topic_name() != self.topic.dds_name() ||
    subscription.type_name() != self.topic.dds_type_name() {
    return Err("the discovered subscription does not match the ROS topic")
  }
  let qos = match subscription.qos() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if qos.reliability() != @rtps.RELIABILITY_BEST_EFFORT {
    return Err("the discovered subscription is not best effort")
  }
  if qos.durability() != @rtps.DURABILITY_VOLATILE {
    return Err("the discovered subscription has incompatible durability")
  }
  for (guid, _) in self.writers {
    if guid == subscription.endpoint_guid() {
      return Ok(())
    }
  }
  let writer = match
    @wire.DataWriter::new_for_subscription(
      self.socket,
      self.guid_prefix,
      self.vendor_id,
      self.writer_id,
      subscription,
      self.next_sequence_number,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  self.writers.push((subscription.endpoint_guid(), writer))
  Ok(())
}

///|
/// Remove a subscription that left the topic.
pub fn RosPublisher::remove_subscription(
  self : RosPublisher,
  endpoint_guid : @rtps.Guid,
) -> Unit {
  let retained : Array[(@rtps.Guid, @wire.DataWriter)] = []
  for (guid, writer) in self.writers {
    if guid != endpoint_guid {
      retained.push((guid, writer))
    }
  }
  self.writers = retained
}

///|
/// Return the ROS topic represented by this publisher.
pub fn RosPublisher::topic(self : RosPublisher) -> @ros_types.RosTopic {
  self.topic
}

///|
/// Return the next RTPS sequence number that will be published.
pub fn RosPublisher::next_sequence_number(self : RosPublisher) -> Int64 {
  self.next_sequence_number
}

///|
/// Publish one CDR-serialized ROS message.
pub async fn RosPublisher::publish(
  self : RosPublisher,
  serialized_payload : Bytes,
) -> Result[Unit, String] {
  let writers : Array[(@rtps.Guid, @wire.DataWriter)] = []
  for target in self.writers {
    writers.push(target)
  }
  self.next_sequence_number += 1L
  for (_, writer) in writers {
    match writer.write(serialized_payload) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(())
}

///|
/// Close the publisher's underlying UDP socket.
pub fn RosPublisher::close(self : RosPublisher) -> Unit {
  self.socket.close()
}

///|
/// A ROS topic subscription backed by a discovered best-effort RTPS publication.
pub struct RosSubscription {
  topic : @ros_types.RosTopic
  reader : @wire.DataReader
}

///|
/// Create a subscription for a discovered publication with a matching topic.
pub fn RosSubscription::new_for_publication(
  topic : @ros_types.RosTopic,
  socket : @wire.Udp,
  reader_id : @rtps.EntityId,
  publication : @rtps.SedpEndpointData,
) -> Result[RosSubscription, String] {
  ros_subscription_for_publication(topic, socket, None, reader_id, publication)
}

///|
/// Create a best-effort subscription that filters INFO_DST for its participant.
pub fn RosSubscription::new_for_publication_with_prefix(
  topic : @ros_types.RosTopic,
  socket : @wire.Udp,
  participant_prefix : @rtps.GuidPrefix,
  reader_id : @rtps.EntityId,
  publication : @rtps.SedpEndpointData,
) -> Result[RosSubscription, String] {
  ros_subscription_for_publication(
    topic,
    socket,
    Some(participant_prefix),
    reader_id,
    publication,
  )
}

///|
fn ros_subscription_for_publication(
  topic : @ros_types.RosTopic,
  socket : @wire.Udp,
  participant_prefix : @rtps.GuidPrefix?,
  reader_id : @rtps.EntityId,
  publication : @rtps.SedpEndpointData,
) -> Result[RosSubscription, String] {
  if publication.topic_name() != topic.dds_name() ||
    publication.type_name() != topic.dds_type_name() {
    return Err("the discovered publication does not match the ROS topic")
  }
  let reader = match
    (match participant_prefix {
      Some(prefix) =>
        @wire.DataReader::new_for_publication_with_prefix(
          socket, prefix, reader_id, publication,
        )
      None =>
        @wire.DataReader::new_for_publication(socket, reader_id, publication)
    }) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ topic, reader, })
}

///|
/// Return the ROS topic represented by this subscription.
pub fn RosSubscription::topic(self : RosSubscription) -> @ros_types.RosTopic {
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
