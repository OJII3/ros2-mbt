///|
/// Internal middleware-facing metadata for a ROS topic endpoint.
/// It deliberately contains ROS names and serialized-message QoS only; the
/// RTPS endpoint identifiers stay inside this package's adapter.
priv struct MiddlewareEndpointInfo {
  topic_name : String
  type_name : String
  type_hash : String
  reliability : Bool
  transient_local : Bool
}

///|
/// A publisher handle at the internal middleware boundary.
/// Callers exchange serialized payloads and do not need the RTPS writer type.
priv struct MiddlewarePublisher {
  writer : ReliableRosPublisher
  // Kept as a shared view for existing whitebox diagnostics.
  writers : Array[ReliableRosTarget]
  info : MiddlewareEndpointInfo
}

///|
/// An attached remote writer as seen by a middleware subscription.
priv struct MiddlewareReader {
  endpoint_guid : @rtps.Guid
  reader : MiddlewareReaderKind
}

///|
priv enum MiddlewareReaderKind {
  BestEffort(RosSubscription)
  Reliable(ReliableRosSubscription)
}

///|
fn MiddlewareReader::new(
  topic : @ros_types.RosTopic,
  socket : @wire.Udp,
  participant_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  reader_id : @rtps.EntityId,
  publication : @rtps.SedpEndpointData,
  reliable : Bool,
) -> Result[MiddlewareReader, String] {
  let endpoint_guid = publication.endpoint_guid()
  let reader = if reliable {
    let sub = match
      ReliableRosSubscription::new_for_publication(
        topic, socket, participant_prefix, vendor_id, reader_id, publication,
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    Reliable(sub)
  } else {
    let sub = match
      RosSubscription::new_for_publication_with_prefix(
        topic, socket, participant_prefix, reader_id, publication,
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    BestEffort(sub)
  }
  Ok({ endpoint_guid, reader, })
}

///|
async fn MiddlewareReader::take(
  self : MiddlewareReader,
  message : @rtps.Message,
  source : @socket.Addr,
) -> Result[Array[Bytes], String] {
  match self.reader {
    BestEffort(reader) => {
      let payload = match reader.handle_message(message, source) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      match payload {
        Some(value) => Ok([value])
        None => Ok([])
      }
    }
    Reliable(reader) => reader.handle_message(message, source)
  }
}

///|
fn MiddlewarePublisher::new(
  writer : ReliableRosPublisher,
  topic : @ros_types.RosTopic,
  type_hash : String,
  qos : @rtps.SedpQos,
) -> MiddlewarePublisher {
  {
    writer,
    writers: writer.writers,
    info: {
      topic_name: topic.ros_name(),
      type_name: topic.dds_type_name(),
      type_hash,
      reliability: qos.reliability() == @rtps.RELIABILITY_RELIABLE,
      transient_local: qos.durability() != @rtps.DURABILITY_VOLATILE,
    },
  }
}

///|
fn MiddlewarePublisher::type_hash(self : MiddlewarePublisher) -> String {
  self.info.type_hash
}

///|
fn MiddlewarePublisher::is_reliable(self : MiddlewarePublisher) -> Bool {
  self.info.reliability
}

///|
fn MiddlewarePublisher::is_transient_local(self : MiddlewarePublisher) -> Bool {
  self.info.transient_local
}

///|
fn MiddlewarePublisher::topic_name(self : MiddlewarePublisher) -> String {
  self.info.topic_name
}

///|
fn MiddlewarePublisher::dds_type_name(self : MiddlewarePublisher) -> String {
  self.info.type_name
}

///|
async fn MiddlewarePublisher::publish(
  self : MiddlewarePublisher,
  payload : Bytes,
) -> Result[Unit, String] {
  self.writer.publish(payload)
}

///|
async fn MiddlewarePublisher::send_heartbeat(
  self : MiddlewarePublisher,
) -> Result[Unit, String] {
  self.writer.send_heartbeat()
}

///|
fn MiddlewarePublisher::add_subscription(
  self : MiddlewarePublisher,
  subscription : @rtps.SedpEndpointData,
) -> Result[Unit, String] {
  self.writer.add_subscription(subscription)
}

///|
fn MiddlewarePublisher::remove_subscription(
  self : MiddlewarePublisher,
  endpoint_guid : @rtps.Guid,
) -> Unit {
  self.writer.remove_subscription(endpoint_guid)
}

///|
fn MiddlewarePublisher::remove_subscriptions_from_participant(
  self : MiddlewarePublisher,
  prefix : @rtps.GuidPrefix,
) -> Unit {
  self.writer.remove_subscriptions_from_participant(prefix)
}

///|
async fn MiddlewarePublisher::handle_message(
  self : MiddlewarePublisher,
  message : @rtps.Message,
) -> Result[Unit, String] {
  self.writer.handle_message(message)
}
