///|
/// A ROS topic name and its DDS-mangled type identity.
pub struct RosTopic {
  ros_name : String
  dds_name : String
  dds_type_name : String
}

///|
/// Create a topic descriptor from a ROS interface path's components.
pub fn RosTopic::new(
  ros_name : String,
  package_name : String,
  interface_namespace : String,
  type_name : String,
) -> Result[RosTopic, String] {
  let dds_name = match ros_topic_to_dds(ros_name) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let dds_type_name = match
    ros_type_to_dds(package_name, interface_namespace, type_name) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ ros_name, dds_name, dds_type_name, })
}

///|
/// Return the original ROS topic name.
pub fn RosTopic::ros_name(self : RosTopic) -> String {
  self.ros_name
}

///|
/// Return the DDS topic name used on the wire.
pub fn RosTopic::dds_name(self : RosTopic) -> String {
  self.dds_name
}

///|
/// Return the DDS type name used in SEDP.
pub fn RosTopic::dds_type_name(self : RosTopic) -> String {
  self.dds_type_name
}

///|
/// Build an SEDP endpoint with the ROS 2 default topic QoS.
pub fn RosTopic::to_sedp(
  self : RosTopic,
  kind : @rtps.SedpEndpointKind,
  endpoint_guid : @rtps.Guid,
) -> Result[@rtps.SedpEndpointData, String] {
  self.to_sedp_with_qos(
    kind,
    endpoint_guid,
    @rtps.SedpQos::new(
      @rtps.RELIABILITY_RELIABLE,
      @rtps.DURABILITY_VOLATILE,
      @rtps.HISTORY_KEEP_LAST,
      10,
    ),
  )
}

///|
/// Build an SEDP endpoint identity with explicit basic DDS QoS.
pub fn RosTopic::to_sedp_with_qos(
  self : RosTopic,
  kind : @rtps.SedpEndpointKind,
  endpoint_guid : @rtps.Guid,
  qos : @rtps.SedpQos,
) -> Result[@rtps.SedpEndpointData, String] {
  if qos.reliability() != @rtps.RELIABILITY_BEST_EFFORT &&
    qos.reliability() != @rtps.RELIABILITY_RELIABLE {
    return Err("ROS topic reliability QoS is invalid")
  }
  if qos.durability() > @rtps.DURABILITY_PERSISTENT {
    return Err("ROS topic durability QoS is invalid")
  }
  if qos.history() != @rtps.HISTORY_KEEP_LAST &&
    qos.history() != @rtps.HISTORY_KEEP_ALL {
    return Err("ROS topic history QoS is invalid")
  }
  if qos.depth() <= 0 {
    return Err("ROS topic history depth must be positive")
  }
  let data_representations = qos.data_representation()
  if data_representations.length() == 0 {
    return Err("ROS topic data representation must not be empty")
  }
  for representation in data_representations {
    if representation != @rtps.DATA_REPRESENTATION_XCDR1 {
      return Err("ROS topic CDR serialization currently supports only XCDR1")
    }
  }
  @rtps.SedpEndpointData::new(
    kind,
    endpoint_guid,
    self.dds_name,
    self.dds_type_name,
  ).map(fn(endpoint) {
    endpoint.add_parameter(@rtps.qos_reliability(qos.reliability(), 0, 0))
    endpoint.add_parameter(@rtps.qos_durability(qos.durability()))
    endpoint.add_parameter(@rtps.qos_history(qos.history(), qos.depth()))
    endpoint.add_parameter(
      @rtps.qos_data_representation(qos.data_representation()),
    )
    endpoint.add_parameter(qos.deadline_parameter())
    endpoint.add_parameter(qos.liveliness_parameter())
    endpoint
  })
}

///|
/// Build an SEDP endpoint and advertise its ROS 2 RIHS01 type hash.
pub fn RosTopic::to_sedp_with_qos_and_type_hash(
  self : RosTopic,
  kind : @rtps.SedpEndpointKind,
  endpoint_guid : @rtps.Guid,
  qos : @rtps.SedpQos,
  type_hash : String,
) -> Result[@rtps.SedpEndpointData, String] {
  self.to_sedp_with_qos(kind, endpoint_guid, qos).map(fn(endpoint) {
    endpoint.add_parameter(@rtps.qos_user_data_type_hash(type_hash))
    endpoint
  })
}
