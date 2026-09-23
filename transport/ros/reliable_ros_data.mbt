///|
struct ReliableRosTarget {
  endpoint_guid : @rtps.Guid
  reliable_writer : @wire.ReliableDataWriter?
  best_effort_writer : @wire.DataWriter?
}

///|
fn reliable_ros_target_new(
  socket : @wire.Udp,
  guid_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  writer_id : @rtps.EntityId,
  subscription : @rtps.SedpEndpointData,
  first_sequence_number : Int64,
) -> Result[ReliableRosTarget, String] {
  let qos = match subscription.qos() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if qos.durability() != @rtps.DURABILITY_VOLATILE {
    return Err("the discovered subscription has incompatible durability")
  }
  if qos.reliability() == @rtps.RELIABILITY_RELIABLE {
    let writer = match
      @wire.ReliableDataWriter::new_for_subscription(
        socket, guid_prefix, vendor_id, writer_id, subscription, first_sequence_number,
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    Ok({
      endpoint_guid: subscription.endpoint_guid(),
      reliable_writer: Some(writer),
      best_effort_writer: None,
    })
  } else {
    let writer = match
      @wire.DataWriter::new_for_subscription(
        socket, guid_prefix, vendor_id, writer_id, subscription, first_sequence_number,
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    Ok({
      endpoint_guid: subscription.endpoint_guid(),
      reliable_writer: None,
      best_effort_writer: Some(writer),
    })
  }
}

///|
/// A reliable ROS topic publisher that can add discovered subscriptions.
pub struct ReliableRosPublisher {
  topic : @ros_types.RosTopic
  socket : @wire.Udp
  guid_prefix : @rtps.GuidPrefix
  vendor_id : @rtps.VendorId
  writer_id : @rtps.EntityId
  mut writers : Array[ReliableRosTarget]
  mut next_sequence_number : Int64
}

///|
/// Create a reliable publisher before any matching subscription is known.
pub fn ReliableRosPublisher::new(
  topic : @ros_types.RosTopic,
  socket : @wire.Udp,
  guid_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  writer_id : @rtps.EntityId,
  first_sequence_number : Int64,
) -> Result[ReliableRosPublisher, String] {
  if first_sequence_number < 1L {
    return Err("an RTPS DATA sequence number must be positive")
  }
  Ok({
    topic,
    socket,
    guid_prefix,
    vendor_id,
    writer_id,
    writers: [],
    next_sequence_number: first_sequence_number,
  })
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
  let publisher = match
    ReliableRosPublisher::new(
      topic, socket, guid_prefix, vendor_id, writer_id, first_sequence_number,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match publisher.add_subscription(subscription) {
    Ok(_) => Ok(publisher)
    Err(message) => Err(message)
  }
}

///|
/// Add a matching discovered subscription to this topic publisher.
pub fn ReliableRosPublisher::add_subscription(
  self : ReliableRosPublisher,
  subscription : @rtps.SedpEndpointData,
) -> Result[Unit, String] {
  if subscription.topic_name() != self.topic.dds_name() ||
    subscription.type_name() != self.topic.dds_type_name() {
    return Err("the discovered subscription does not match the ROS topic")
  }
  for target in self.writers {
    if target.endpoint_guid == subscription.endpoint_guid() {
      return Ok(())
    }
  }
  let target = match
    reliable_ros_target_new(
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
  self.writers.push(target)
  Ok(())
}

///|
/// Remove a subscription that left the topic.
pub fn ReliableRosPublisher::remove_subscription(
  self : ReliableRosPublisher,
  endpoint_guid : @rtps.Guid,
) -> Unit {
  let retained : Array[ReliableRosTarget] = []
  for target in self.writers {
    if target.endpoint_guid != endpoint_guid {
      retained.push(target)
    }
  }
  self.writers = retained
}

///|
/// Remove all subscriptions owned by a participant that left the domain.
pub fn ReliableRosPublisher::remove_subscriptions_from_participant(
  self : ReliableRosPublisher,
  participant_prefix : @rtps.GuidPrefix,
) -> Unit {
  let retained : Array[ReliableRosTarget] = []
  for target in self.writers {
    if target.endpoint_guid.prefix() != participant_prefix {
      retained.push(target)
    }
  }
  self.writers = retained
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
  self.next_sequence_number
}

///|
/// Return the number of samples retained for retransmission.
pub fn ReliableRosPublisher::history_length(self : ReliableRosPublisher) -> Int {
  let mut length = 0
  for target in self.writers {
    match target.reliable_writer {
      Some(writer) => {
        let writer_length = writer.history_length()
        if writer_length > length {
          length = writer_length
        }
      }
      None => ()
    }
  }
  length
}

///|
/// Publish one CDR-serialized ROS message and retain it for retransmission.
///
/// If no matching subscriptions have been added, this advances the writer
/// sequence number without sending the sample. Later subscriptions receive
/// only subsequent samples.
pub async fn ReliableRosPublisher::publish(
  self : ReliableRosPublisher,
  serialized_payload : Bytes,
) -> Result[Unit, String] {
  let writers : Array[ReliableRosTarget] = []
  for target in self.writers {
    writers.push(target)
  }
  self.next_sequence_number += 1L
  for target in writers {
    match target.reliable_writer {
      Some(writer) =>
        match writer.write(serialized_payload) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      None =>
        match target.best_effort_writer {
          Some(writer) =>
            match writer.write(serialized_payload) {
              Ok(_) => ()
              Err(message) => return Err(message)
            }
          None => ()
        }
    }
  }
  Ok(())
}

///|
/// Announce the retained samples to the remote reliable reader.
pub async fn ReliableRosPublisher::send_heartbeat(
  self : ReliableRosPublisher,
) -> Result[Unit, String] {
  let writers : Array[ReliableRosTarget] = []
  for target in self.writers {
    writers.push(target)
  }
  for target in writers {
    match target.reliable_writer {
      Some(writer) =>
        match writer.send_heartbeat() {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      None => ()
    }
  }
  Ok(())
}

///|
/// Receive a matching ACKNACK and retransmit requested samples.
pub async fn ReliableRosPublisher::receive_acknack(
  self : ReliableRosPublisher,
) -> Result[(@rtps.AckNackSubmessage, @socket.Addr), String] {
  while true {
    let (message, source) = match self.socket.receive_message() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    for target in self.writers {
      match target.reliable_writer {
        Some(writer) =>
          match writer.handle_control_message(message) {
            Ok(true) =>
              for submessage in message.submessages() {
                if submessage.id() == @rtps.SubmessageId::AckNack {
                  match @rtps.AckNackSubmessage::from_submessage(submessage) {
                    Ok(value) => return Ok((value, source))
                    Err(message) => return Err(message)
                  }
                }
              }
            Ok(false) => ()
            Err(message) => return Err(message)
          }
        None => ()
      }
    }
  }
  Err("reliable publisher stopped")
}

///|
/// Apply an ACKNACK directly and retransmit requested samples.
pub async fn ReliableRosPublisher::handle_acknack(
  self : ReliableRosPublisher,
  acknack : @rtps.AckNackSubmessage,
) -> Result[Unit, String] {
  for target in self.writers {
    match target.reliable_writer {
      Some(writer) =>
        match writer.handle_acknack(acknack) {
          Ok(_) => return Ok(())
          Err(_) => ()
        }
      None => ()
    }
  }
  Err("the ACKNACK does not match a discovered subscription")
}

///|
/// Receive a matching NACK_FRAG and retransmit requested fragments.
pub async fn ReliableRosPublisher::receive_nackfrag(
  self : ReliableRosPublisher,
) -> Result[(@rtps.NackFragSubmessage, @socket.Addr), String] {
  while true {
    let (message, source) = match self.socket.receive_message() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    for target in self.writers {
      match target.reliable_writer {
        Some(writer) =>
          match writer.handle_control_message(message) {
            Ok(true) =>
              for submessage in message.submessages() {
                if submessage.id() == @rtps.SubmessageId::NackFrag {
                  match @rtps.NackFragSubmessage::from_submessage(submessage) {
                    Ok(value) => return Ok((value, source))
                    Err(message) => return Err(message)
                  }
                }
              }
            Ok(false) => ()
            Err(message) => return Err(message)
          }
        None => ()
      }
    }
  }
  Err("reliable publisher stopped")
}

///|
/// Receive either ACKNACK or NACK_FRAG and retransmit the requested samples.
pub async fn ReliableRosPublisher::receive_control(
  self : ReliableRosPublisher,
) -> Result[Unit, String] {
  while true {
    let (message, _) = match self.socket.receive_message() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    for target in self.writers {
      match target.reliable_writer {
        Some(writer) =>
          match writer.handle_control_message(message) {
            Ok(true) => break
            Ok(false) => ()
            Err(message) => return Err(message)
          }
        None => ()
      }
    }
  }
  Err("reliable publisher stopped")
}

///|
/// Apply a NACK_FRAG directly and retransmit requested fragments.
pub async fn ReliableRosPublisher::handle_nackfrag(
  self : ReliableRosPublisher,
  nackfrag : @rtps.NackFragSubmessage,
) -> Result[Unit, String] {
  for target in self.writers {
    match target.reliable_writer {
      Some(writer) =>
        match writer.handle_nackfrag(nackfrag) {
          Ok(_) => return Ok(())
          Err(_) => ()
        }
      None => ()
    }
  }
  Err("the NACK_FRAG does not match a discovered subscription")
}

///|
/// Close the publisher's underlying UDP socket.
pub fn ReliableRosPublisher::close(self : ReliableRosPublisher) -> Unit {
  self.socket.close()
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
