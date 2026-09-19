///|
test "ROS service descriptor maps request and response endpoints" {
  let service = match
    RosService::new("/add_two_ints", "example_interfaces", "AddTwoInts") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(service.ros_name(), "/add_two_ints")
  assert_eq(service.dds_request_name(), "rq/add_two_ints")
  assert_eq(service.dds_response_name(), "rr/add_two_ints")
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
  assert_eq(request.topic_name(), "rq/add_two_ints")
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
  assert_eq(response.topic_name(), "rr/add_two_ints")
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
