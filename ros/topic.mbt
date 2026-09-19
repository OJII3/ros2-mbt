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
/// Build an SEDP endpoint identity for this ROS topic.
pub fn RosTopic::to_sedp(
  self : RosTopic,
  kind : @rtps.SedpEndpointKind,
  endpoint_guid : @rtps.Guid,
) -> Result[@rtps.SedpEndpointData, String] {
  @rtps.SedpEndpointData::new(
    kind,
    endpoint_guid,
    self.dds_name,
    self.dds_type_name,
  )
}
