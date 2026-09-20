///|
test "Cyclone DDS service payload header round trips" {
  let body_writer = @cdr.Writer::new()
  body_writer.write_i64(2L)
  body_writer.write_i64(3L)
  let client_id = 9L.reinterpret_as_uint64()
  let header = @ros.RosServicePayloadHeader::new(client_id, 12L)
  let encoded = header.to_cdr_payload(body_writer.to_bytes()).unwrap()
  assert_eq(encoded.length(), 36)
  assert_eq(encoded[0], 0)
  assert_eq(encoded[1], 1)
  assert_eq(encoded[4], 9)
  assert_eq(encoded[12], 12)
  assert_eq(encoded[20], 2)
  let (decoded_header, decoded_body) = @ros.ros_service_payload_from_cdr(
    encoded,
  ).unwrap()
  assert_eq(decoded_header, header)
  assert_eq(decoded_body, body_writer.to_bytes())
}

///|
test "ROS service descriptor maps request and response endpoints" {
  let service = match
    RosService::new("/add_two_ints", "example_interfaces", "AddTwoInts") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(service.ros_name(), "/add_two_ints")
  assert_eq(service.dds_request_name(), "rq/add_two_intsRequest")
  assert_eq(service.dds_response_name(), "rr/add_two_intsReply")
  assert_eq(
    service.dds_request_type_name(),
    "example_interfaces::srv::dds_::AddTwoInts_Request_",
  )
  assert_eq(
    service.dds_response_type_name(),
    "example_interfaces::srv::dds_::AddTwoInts_Response_",
  )
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let endpoint_id = match @rtps.EntityId::new(b"svc", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let request = match
    service.request_to_sedp(
      @rtps.SedpEndpointKind::Publication,
      @rtps.Guid::new(prefix, endpoint_id),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(request.topic_name(), "rq/add_two_intsRequest")
  assert_eq(
    request.type_name(),
    "example_interfaces::srv::dds_::AddTwoInts_Request_",
  )
  let request_qos = match request.qos() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(request_qos.reliability(), @rtps.RELIABILITY_RELIABLE)
  assert_eq(request_qos.depth(), 10)
  let response = match
    service.response_to_sedp(
      @rtps.SedpEndpointKind::Subscription,
      @rtps.Guid::new(prefix, endpoint_id),
    ) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(response.topic_name(), "rr/add_two_intsReply")
  assert_eq(
    response.type_name(),
    "example_interfaces::srv::dds_::AddTwoInts_Response_",
  )
}

///|
test "ROS service rejects incompatible QoS" {
  let service = match RosService::new("/service", "pkg", "Type") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let endpoint_id = match @rtps.EntityId::new(b"svc", 0xC2) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_true(
    service.request_to_sedp_with_qos(
      @rtps.SedpEndpointKind::Publication,
      @rtps.Guid::new(prefix, endpoint_id),
      @rtps.SedpQos::new(
        @rtps.RELIABILITY_BEST_EFFORT,
        @rtps.DURABILITY_VOLATILE,
        @rtps.HISTORY_KEEP_LAST,
        10,
      ),
    )
    is Err(_),
  )
}

///|
test "ROS service SEDP links request and response endpoints" {
  let service = RosService::new(
    "/add_two_ints", "example_interfaces", "AddTwoInts",
  ).unwrap()
  let prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let request_id = @rtps.EntityId::new(b"req", 0xC2).unwrap()
  let response_id = @rtps.EntityId::new(b"res", 0xC7).unwrap()
  let request_guid = @rtps.Guid::new(prefix, request_id)
  let response_guid = @rtps.Guid::new(prefix, response_id)
  let request = service
    .request_to_sedp_with_related_endpoint(
      @rtps.SedpEndpointKind::Publication,
      request_guid,
      response_guid,
    )
    .unwrap()
  let response = service
    .response_to_sedp_with_related_endpoint(
      @rtps.SedpEndpointKind::Subscription,
      response_guid,
      request_guid,
    )
    .unwrap()
  let decoded_request = @rtps.SedpEndpointData::from_cdr_bytes(
    @rtps.SedpEndpointKind::Publication,
    request.to_cdr_bytes().unwrap(),
  ).unwrap()
  let decoded_response = @rtps.SedpEndpointData::from_cdr_bytes(
    @rtps.SedpEndpointKind::Subscription,
    response.to_cdr_bytes().unwrap(),
  ).unwrap()
  let request_parameters = decoded_request.to_parameter_list().unwrap().values()
  let response_parameters = decoded_response
    .to_parameter_list()
    .unwrap()
    .values()
  let mut request_related : Bytes? = None
  let mut response_related : Bytes? = None
  for parameter in request_parameters {
    if parameter.id() == @rtps.PID_RELATED_ENTITY_GUID {
      request_related = Some(parameter.value())
    }
  }
  for parameter in response_parameters {
    if parameter.id() == @rtps.PID_RELATED_ENTITY_GUID {
      response_related = Some(parameter.value())
    }
  }
  assert_eq(request_related, Some(response_guid.to_bytes()))
  assert_eq(response_related, Some(request_guid.to_bytes()))
}

///|
test "ROS service SEDP can advertise request and response type hashes" {
  let service = RosService::new(
    "/add_two_ints", "example_interfaces", "AddTwoInts",
  ).unwrap()
  let prefix = @rtps.GuidPrefix::from_array([
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ]).unwrap()
  let request_guid = @rtps.Guid::new(
    prefix,
    @rtps.EntityId::new(b"req", 0xC7).unwrap(),
  )
  let response_guid = @rtps.Guid::new(
    prefix,
    @rtps.EntityId::new(b"res", 0xC2).unwrap(),
  )
  let request_hash = "RIHS01_request_hash"
  let response_hash = "RIHS01_response_hash"
  let request = service
    .request_to_sedp_with_qos_and_type_hash(
      @rtps.SedpEndpointKind::Subscription,
      request_guid,
      @rtps.SedpQos::new(
        @rtps.RELIABILITY_RELIABLE,
        @rtps.DURABILITY_VOLATILE,
        @rtps.HISTORY_KEEP_LAST,
        10,
      ),
      request_hash,
    )
    .unwrap()
  let response = service
    .response_to_sedp_with_qos_and_type_hash(
      @rtps.SedpEndpointKind::Publication,
      response_guid,
      @rtps.SedpQos::new(
        @rtps.RELIABILITY_RELIABLE,
        @rtps.DURABILITY_VOLATILE,
        @rtps.HISTORY_KEEP_LAST,
        10,
      ),
      response_hash,
    )
    .unwrap()
  assert_eq(request.type_hash(), Ok(Some(request_hash)))
  assert_eq(response.type_hash(), Ok(Some(response_hash)))
}
