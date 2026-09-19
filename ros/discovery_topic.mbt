///|
/// DDS topic name used for ROS graph discovery.
pub const ROS_DISCOVERY_INFO_TOPIC_NAME : String = "ros_discovery_info"

///|
/// DDS type name used for ROS graph discovery.
pub const ROS_DISCOVERY_INFO_TYPE_NAME : String = "rmw_dds_common::msg::dds_::ParticipantEntitiesInfo_"

///|
/// Create the SEDP identity and QoS for the ROS graph-discovery endpoint.
pub fn ros_discovery_info_to_sedp(
  kind : @rtps.SedpEndpointKind,
  endpoint_guid : @rtps.Guid,
) -> Result[@rtps.SedpEndpointData, String] {
  let endpoint = match
    @rtps.SedpEndpointData::new(
      kind,
      endpoint_guid,
      ROS_DISCOVERY_INFO_TOPIC_NAME,
      ROS_DISCOVERY_INFO_TYPE_NAME,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  endpoint.add_parameter(
    @rtps.qos_reliability(@rtps.RELIABILITY_RELIABLE, 0, 0),
  )
  endpoint.add_parameter(@rtps.qos_durability(@rtps.DURABILITY_TRANSIENT_LOCAL))
  match kind {
    @rtps.SedpEndpointKind::Publication =>
      endpoint.add_parameter(@rtps.qos_history(@rtps.HISTORY_KEEP_LAST, 1))
    @rtps.SedpEndpointKind::Subscription =>
      endpoint.add_parameter(@rtps.qos_history(@rtps.HISTORY_KEEP_ALL, 1))
  }
  Ok(endpoint)
}
