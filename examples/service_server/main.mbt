///|
/// Discover the service endpoints.
async fn discover_service(
  participant : @transport.RosParticipant,
  service : @ros.RosService,
) -> Result[(@rtps.SedpEndpointData, @rtps.SedpEndpointData), String] {
  let mut request_publication : @rtps.SedpEndpointData? = None
  let mut response_subscription : @rtps.SedpEndpointData? = None
  // Graph discovery may already have consumed these SEDP events.
  for publication in participant.graph().publications() {
    if publication.topic_name() == service.dds_request_name() &&
      publication.type_name() == service.dds_request_type_name() {
      request_publication = Some(publication)
    }
  }
  for subscription in participant.graph().subscriptions() {
    if subscription.topic_name() == service.dds_response_name() &&
      subscription.type_name() == service.dds_response_type_name() {
      response_subscription = Some(subscription)
    }
  }
  while request_publication is None || response_subscription is None {
    match participant.receive_discovery_once() {
      Ok((_, Publication(publication))) =>
        if publication.topic_name() == service.dds_request_name() &&
          publication.type_name() == service.dds_request_type_name() {
          request_publication = Some(publication)
        }
      Ok((_, Subscription(subscription))) =>
        if subscription.topic_name() == service.dds_response_name() &&
          subscription.type_name() == service.dds_response_type_name() {
          response_subscription = Some(subscription)
        }
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  match (request_publication, response_subscription) {
    (Some(request_publication), Some(response_subscription)) =>
      Ok((request_publication, response_subscription))
    _ => Err("discovery ended without matching service endpoints")
  }
}

///|
/// Serve one `example_interfaces/srv/AddTwoInts` request over ROS 2 DDS.
async fn main {
  let config = match @config.load() {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let prefix = match
    @rtps.GuidPrefix::from_array([
      0x4D, 0x42, 0x54, 0x52, 0x50, 0x53, 0, 0, 0, 0, 0, 44,
    ]) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let vendor_id = @rtps.VendorId::new(1, 15)
  let service = match
    @ros.RosService::new("/add_two_ints", "example_interfaces", "AddTwoInts") {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let request_reader_id = match @rtps.EntityId::new(b"\x00\x00\x2C", 0x04) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let response_writer_id = match @rtps.EntityId::new(b"\x00\x00\x2D", 0x03) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let graph_publication_id = match
    @rtps.EntityId::new(b"gph", @ros.ROS_GRAPH_PUBLICATION_ENTITY_KIND) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let graph_subscription_id = match
    @rtps.EntityId::new(b"gph", @ros.ROS_GRAPH_SUBSCRIPTION_ENTITY_KIND) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let participant = match
    @transport.RosParticipant::new_ddsi(
      prefix,
      vendor_id,
      config.domain_id,
      44U,
      config.ip,
      60,
      1L,
      multicast_interface?=config.multicast_interface,
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  match participant.set_ros_node_identity("/demo", "moon_add_two_ints_server") {
    Ok(_) => ()
    Err(message) => {
      println(message)
      participant.close()
      return
    }
  }
  match
    participant.register_ros_discovery_info(
      graph_publication_id, graph_subscription_id,
    ) {
    Ok(_) => ()
    Err(message) => {
      println(message)
      participant.close()
      return
    }
  }
  match
    participant.register_service_server_with_type_hashes(
      service, request_reader_id, response_writer_id, "RIHS01_000c5fd92d6b2e1a05949348f584d6d652adea1e92d691792011ac2273508302",
      "RIHS01_de5c030d4af33cba2749310b249737b631594703f9300495f48bffb2b44dcc2f",
    ) {
    Ok(_) => ()
    Err(message) => {
      println(message)
      participant.close()
      return
    }
  }
  match
    serve_once(
      participant, service, prefix, vendor_id, request_reader_id, response_writer_id,
    ) {
    Ok(_) => println("served AddTwoInts request")
    Err(message) => println(message)
  }
  participant.close()
}

///|
priv enum ServerEvent {
  Incoming(Result[(@rtps.Message, @socket.Addr), String])
  Discovered(Result[(@rtps.SedpEndpointData, @rtps.SedpEndpointData), String])
  Heartbeat
}

///|
async fn serve_once(
  participant : @transport.RosParticipant,
  service : @ros.RosService,
  prefix : @rtps.GuidPrefix,
  vendor_id : @rtps.VendorId,
  request_reader_id : @rtps.EntityId,
  response_writer_id : @rtps.EntityId,
) -> Result[Unit, String] {
  @async.with_task_group() <| group => {
    let events : @aqueue.Queue[ServerEvent] = @aqueue.Queue(
      kind=@aqueue.Unbounded,
    )
    group.spawn_bg(no_wait=true) <| () => {
      let result = discover_service(participant, service)
      events.put(Discovered(result))
      if result is Ok(_) {
        while true {
          match participant.receive_discovery_once() {
            Ok(_) => ()
            Err(message) => {
              events.put(Discovered(Err(message)))
              break
            }
          }
        }
      }
    }
    group.spawn_bg(no_wait=true) <| () => {
      while true {
        let incoming = participant.user_socket().receive_message()
        events.put(Incoming(incoming))
        if incoming is Err(_) {
          break
        }
      }
    }
    group.spawn_bg(no_wait=true) <| () => {
      while true {
        events.put(Heartbeat)
        @async.sleep(1000)
      }
    }
    let mut server : @transport.RosServiceServer? = None
    let early_requests : Array[(@rtps.Message, @socket.Addr)] = []
    while true {
      match events.get() {
        Heartbeat => {
          match participant.announce_spdp_once() {
            Ok(_) => ()
            Err(message) => return Err(message)
          }
          match participant.send_ros_discovery_heartbeats() {
            Ok(_) => ()
            Err(message) => return Err(message)
          }
        }
        Discovered(Err(message)) | Incoming(Err(message)) => return Err(message)
        Discovered(Ok((request_publication, response_subscription))) => {
          let wire_format = match
            participant
            .graph()
            .participant_vendor_id(request_publication.participant_guid()) {
            Some(vendor) if vendor == @rtps.VendorId::new(1, 16) =>
              @transport.RosServiceWireFormat::CycloneDdsPayload
            _ => DdsRpcInline
          }
          let ready = match
            @transport.RosServiceServer::new_with_shared_socket_and_wire_format(
              service,
              participant.user_socket(),
              prefix,
              vendor_id,
              request_reader_id,
              request_publication,
              response_writer_id,
              response_subscription,
              1L,
              wire_format,
            ) {
            Ok(server) => server
            Err(message) => return Err(message)
          }
          for (message, source) in early_requests {
            match ready.handle_message(message, source) {
              Ok(_) => ()
              Err(message) => return Err(message)
            }
          }
          early_requests.clear()
          server = Some(ready)
        }
        Incoming(Ok((message, source))) => {
          match participant.handle_user_message(message, source) {
            Ok(_) => ()
            Err(message) => return Err(message)
          }
          match server {
            Some(server) =>
              match server.handle_message(message, source) {
                Ok(_) => ()
                Err(message) => return Err(message)
              }
            None => {
              // Preserve requests that arrive before both client endpoints.
              let mut is_request = false
              for submessage in message.submessages() {
                match submessage.id() {
                  Data =>
                    match @rtps.DataSubmessage::from_submessage(submessage) {
                      Ok(data) if data.reader_id() == request_reader_id ||
                        data.reader_id() == @rtps.EntityId::unknown() =>
                        is_request = true
                      _ => ()
                    }
                  DataFrag =>
                    match
                      @rtps.DataFragSubmessage::from_submessage(submessage) {
                      Ok(data) if data.reader_id() == request_reader_id ||
                        data.reader_id() == @rtps.EntityId::unknown() =>
                        is_request = true
                      _ => ()
                    }
                  _ => ()
                }
              }
              if is_request {
                early_requests.push((message, source))
              }
            }
          }
        }
      }
      match server {
        Some(server) =>
          match server.take_request() {
            Ok(Some((payload, identity, _))) => {
              let reader = match @cdr.Reader::from_bytes(payload) {
                Ok(reader) => reader
                Err(message) => return Err(message)
              }
              let a = match reader.read_i64() {
                Ok(value) => value
                Err(message) => return Err(message)
              }
              let b = match reader.read_i64() {
                Ok(value) => value
                Err(message) => return Err(message)
              }
              let response = @cdr.Writer::new()
              response.write_i64(a + b)
              return server.respond(identity, response.to_bytes())
            }
            Ok(None) => ()
            Err(message) => return Err(message)
          }
        None => ()
      }
    } nobreak {
      Err("service dispatcher stopped")
    }
  }
}
