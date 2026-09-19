///|
/// A ROS 2 service mapped to its request and response DDS topics.
pub struct RosService {
  ros_name : String
  dds_request_name : String
  dds_response_name : String
  dds_request_type_name : String
  dds_response_type_name : String
} derive(Eq, Debug)

///|
/// Create a service descriptor for a `package/srv/Service` interface.
pub fn RosService::new(
  ros_name : String,
  package_name : String,
  service_name : String,
) -> Result[RosService, String] {
  let dds_request_name = match ros_service_request_to_dds(ros_name) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let dds_response_name = match ros_service_response_to_dds(ros_name) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let dds_request_type_name = match
    ros_type_to_dds(package_name, "srv", service_name + "_Request") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let dds_response_type_name = match
    ros_type_to_dds(package_name, "srv", service_name + "_Response") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({
    ros_name,
    dds_request_name,
    dds_response_name,
    dds_request_type_name,
    dds_response_type_name,
  })
}

///|
pub fn RosService::ros_name(self : RosService) -> String {
  self.ros_name
}

///|
pub fn RosService::dds_request_name(self : RosService) -> String {
  self.dds_request_name
}

///|
pub fn RosService::dds_response_name(self : RosService) -> String {
  self.dds_response_name
}

///|
pub fn RosService::dds_request_type_name(self : RosService) -> String {
  self.dds_request_type_name
}

///|
pub fn RosService::dds_response_type_name(self : RosService) -> String {
  self.dds_response_type_name
}

///|
/// Build the SEDP endpoint identity for a service request endpoint.
pub fn RosService::request_to_sedp(
  self : RosService,
  kind : @rtps.SedpEndpointKind,
  endpoint_guid : @rtps.Guid,
) -> Result[@rtps.SedpEndpointData, String] {
  service_endpoint_to_sedp(
    kind,
    endpoint_guid,
    self.dds_request_name,
    self.dds_request_type_name,
    @rtps.SedpQos::new(
      @rtps.RELIABILITY_RELIABLE,
      @rtps.DURABILITY_VOLATILE,
      @rtps.HISTORY_KEEP_LAST,
      10,
    ),
    None,
  )
}

///|
/// Build a service request SEDP endpoint with explicit DDS QoS.
pub fn RosService::request_to_sedp_with_qos(
  self : RosService,
  kind : @rtps.SedpEndpointKind,
  endpoint_guid : @rtps.Guid,
  qos : @rtps.SedpQos,
) -> Result[@rtps.SedpEndpointData, String] {
  service_endpoint_to_sedp(
    kind,
    endpoint_guid,
    self.dds_request_name,
    self.dds_request_type_name,
    qos,
    None,
  )
}

///|
/// Build a service request SEDP endpoint linked to its response endpoint.
pub fn RosService::request_to_sedp_with_related_endpoint(
  self : RosService,
  kind : @rtps.SedpEndpointKind,
  endpoint_guid : @rtps.Guid,
  related_endpoint_guid : @rtps.Guid,
) -> Result[@rtps.SedpEndpointData, String] {
  service_endpoint_to_sedp(
    kind,
    endpoint_guid,
    self.dds_request_name,
    self.dds_request_type_name,
    @rtps.SedpQos::new(
      @rtps.RELIABILITY_RELIABLE,
      @rtps.DURABILITY_VOLATILE,
      @rtps.HISTORY_KEEP_LAST,
      10,
    ),
    Some(related_endpoint_guid),
  )
}

///|
/// Build the SEDP endpoint identity for a service response endpoint.
pub fn RosService::response_to_sedp(
  self : RosService,
  kind : @rtps.SedpEndpointKind,
  endpoint_guid : @rtps.Guid,
) -> Result[@rtps.SedpEndpointData, String] {
  service_endpoint_to_sedp(
    kind,
    endpoint_guid,
    self.dds_response_name,
    self.dds_response_type_name,
    @rtps.SedpQos::new(
      @rtps.RELIABILITY_RELIABLE,
      @rtps.DURABILITY_VOLATILE,
      @rtps.HISTORY_KEEP_LAST,
      10,
    ),
    None,
  )
}

///|
/// Build a service response SEDP endpoint with explicit DDS QoS.
pub fn RosService::response_to_sedp_with_qos(
  self : RosService,
  kind : @rtps.SedpEndpointKind,
  endpoint_guid : @rtps.Guid,
  qos : @rtps.SedpQos,
) -> Result[@rtps.SedpEndpointData, String] {
  service_endpoint_to_sedp(
    kind,
    endpoint_guid,
    self.dds_response_name,
    self.dds_response_type_name,
    qos,
    None,
  )
}

///|
/// Build a service response SEDP endpoint linked to its request endpoint.
pub fn RosService::response_to_sedp_with_related_endpoint(
  self : RosService,
  kind : @rtps.SedpEndpointKind,
  endpoint_guid : @rtps.Guid,
  related_endpoint_guid : @rtps.Guid,
) -> Result[@rtps.SedpEndpointData, String] {
  service_endpoint_to_sedp(
    kind,
    endpoint_guid,
    self.dds_response_name,
    self.dds_response_type_name,
    @rtps.SedpQos::new(
      @rtps.RELIABILITY_RELIABLE,
      @rtps.DURABILITY_VOLATILE,
      @rtps.HISTORY_KEEP_LAST,
      10,
    ),
    Some(related_endpoint_guid),
  )
}

///|
fn service_endpoint_to_sedp(
  kind : @rtps.SedpEndpointKind,
  endpoint_guid : @rtps.Guid,
  topic_name : String,
  type_name : String,
  qos : @rtps.SedpQos,
  related_endpoint_guid : @rtps.Guid?,
) -> Result[@rtps.SedpEndpointData, String] {
  if qos.reliability() != @rtps.RELIABILITY_RELIABLE {
    return Err("ROS service reliability QoS must be reliable")
  }
  if qos.durability() != @rtps.DURABILITY_VOLATILE {
    return Err("ROS service durability QoS must be volatile")
  }
  if qos.history() != @rtps.HISTORY_KEEP_LAST || qos.depth() <= 0 {
    return Err("ROS service history must be positive KEEP_LAST")
  }
  @rtps.SedpEndpointData::new(kind, endpoint_guid, topic_name, type_name).map(fn(
    endpoint,
  ) {
    endpoint.add_parameter(@rtps.qos_reliability(qos.reliability(), 0, 0))
    endpoint.add_parameter(@rtps.qos_durability(qos.durability()))
    endpoint.add_parameter(@rtps.qos_history(qos.history(), qos.depth()))
    endpoint.add_parameter(
      @rtps.qos_data_representation([@rtps.DATA_REPRESENTATION_XCDR1]),
    )
    match related_endpoint_guid {
      Some(guid) =>
        endpoint.add_parameter(
          @rtps.Parameter::new(@rtps.PID_RELATED_ENTITY_GUID, guid.to_bytes()),
        )
      None => ()
    }
    endpoint
  })
}
