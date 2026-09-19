///|
/// Validate one discovered endpoint against a ROS service role.
fn validate_service_endpoint(
  endpoint : @rtps.SedpEndpointData,
  kind : @rtps.SedpEndpointKind,
  topic_name : String,
  type_name : String,
) -> Result[Unit, String] {
  if endpoint.kind() != kind {
    return Err("the discovered endpoint has the wrong service role")
  }
  if endpoint.topic_name() != topic_name || endpoint.type_name() != type_name {
    return Err("the discovered endpoint does not match the ROS service")
  }
  let qos = match endpoint.qos() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if qos.reliability() != @rtps.RELIABILITY_RELIABLE ||
    qos.durability() != @rtps.DURABILITY_VOLATILE {
    return Err("the discovered service endpoint has incompatible QoS")
  }
  Ok(())
}

///|
/// A ROS service client using reliable request/reply DATA endpoints.
pub struct RosServiceClient {
  service : @ros.RosService
  request_writer : ReliableDataWriter
  response_reader : ReliableDataReaderSession
}

///|
/// Create a client from the discovered service request subscription and
/// response publication.
pub fn RosServiceClient::new(
  service : @ros.RosService,
  request_socket : Udp,
  response_socket : Udp,
  guid_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  request_writer_id : @rtps.EntityId,
  request_subscription : @rtps.SedpEndpointData,
  response_reader_id : @rtps.EntityId,
  response_publication : @rtps.SedpEndpointData,
  first_request_sequence_number : Int64,
) -> Result[RosServiceClient, String] {
  match
    validate_service_endpoint(
      request_subscription,
      @rtps.SedpEndpointKind::Subscription,
      service.dds_request_name(),
      service.dds_request_type_name(),
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match
    validate_service_endpoint(
      response_publication,
      @rtps.SedpEndpointKind::Publication,
      service.dds_response_name(),
      service.dds_response_type_name(),
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let request_writer = match
    ReliableDataWriter::new_for_subscription(
      request_socket, guid_prefix, vendor_id, request_writer_id, request_subscription,
      first_request_sequence_number,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let response_reader = match
    ReliableDataReaderSession::new_for_publication(
      response_socket, guid_prefix, vendor_id, response_reader_id, response_publication,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ service, request_writer, response_reader, })
}

///|
pub fn RosServiceClient::service(self : RosServiceClient) -> @ros.RosService {
  self.service
}

///|
/// Send one request and announce it to the reliable service reader.
pub async fn RosServiceClient::request(
  self : RosServiceClient,
  serialized_request : Bytes,
) -> Result[@rtps.SampleIdentity, String] {
  let identity = match
    self.request_writer.write_and_return_identity(serialized_request) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match self.request_writer.send_heartbeat() {
    Ok(_) => Ok(identity)
    Err(message) => Err(message)
  }
}

///|
/// Receive the response associated with a previously sent request.
pub async fn RosServiceClient::receive_response(
  self : RosServiceClient,
  request_identity : @rtps.SampleIdentity,
) -> Result[(Bytes, @socket.Addr), String] {
  let (data, source) = match
    self.response_reader.receive_related_data(request_identity) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok((data.serialized_payload(), source))
}

///|
pub fn RosServiceClient::close(self : RosServiceClient) -> Unit {
  self.request_writer.close()
  self.response_reader.close()
}

///|
/// A ROS service server using reliable request/reply DATA endpoints.
pub struct RosServiceServer {
  service : @ros.RosService
  request_reader : ReliableDataReaderSession
  response_writer : ReliableDataWriter
}

///|
/// Create a server from the discovered service request publication and
/// response subscription.
pub fn RosServiceServer::new(
  service : @ros.RosService,
  request_socket : Udp,
  response_socket : Udp,
  guid_prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  request_reader_id : @rtps.EntityId,
  request_publication : @rtps.SedpEndpointData,
  response_writer_id : @rtps.EntityId,
  response_subscription : @rtps.SedpEndpointData,
  first_response_sequence_number : Int64,
) -> Result[RosServiceServer, String] {
  match
    validate_service_endpoint(
      request_publication,
      @rtps.SedpEndpointKind::Publication,
      service.dds_request_name(),
      service.dds_request_type_name(),
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match
    validate_service_endpoint(
      response_subscription,
      @rtps.SedpEndpointKind::Subscription,
      service.dds_response_name(),
      service.dds_response_type_name(),
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let request_reader = match
    ReliableDataReaderSession::new_for_publication(
      request_socket, guid_prefix, vendor_id, request_reader_id, request_publication,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let response_writer = match
    ReliableDataWriter::new_for_subscription(
      response_socket, guid_prefix, vendor_id, response_writer_id, response_subscription,
      first_response_sequence_number,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ service, request_reader, response_writer, })
}

///|
pub fn RosServiceServer::service(self : RosServiceServer) -> @ros.RosService {
  self.service
}

///|
/// Receive a request and its RTPS sample identity.
pub async fn RosServiceServer::receive_request(
  self : RosServiceServer,
) -> Result[(Bytes, @rtps.SampleIdentity, @socket.Addr), String] {
  let (data, identity, source) = match
    self.request_reader.receive_data_with_identity() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok((data.serialized_payload(), identity, source))
}

///|
/// Send a response correlated with the received request.
pub async fn RosServiceServer::respond(
  self : RosServiceServer,
  request_identity : @rtps.SampleIdentity,
  serialized_response : Bytes,
) -> Result[Unit, String] {
  match
    self.response_writer.write_with_related_sample_identity(
      serialized_response, request_identity,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  self.response_writer.send_heartbeat()
}

///|
pub fn RosServiceServer::close(self : RosServiceServer) -> Unit {
  self.request_reader.close()
  self.response_writer.close()
}
