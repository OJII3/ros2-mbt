///|
/// DDS topic name used for ROS graph discovery.
pub const ROS_DISCOVERY_INFO_TOPIC_NAME : String = "ros_discovery_info"

///|
/// DDS type name used for ROS graph discovery.
pub const ROS_DISCOVERY_INFO_TYPE_NAME : String = "rmw_dds_common::msg::dds_::ParticipantEntitiesInfo_"

///|
/// RIHS01 type hash for `rmw_dds_common/msg/ParticipantEntitiesInfo`.
pub const ROS_DISCOVERY_INFO_TYPE_HASH : String = "RIHS01_91a0593bacdcc50ea9bdcf849a938b128412cc1ea821245c663bcd26f83c295e"

///|
/// Standard user entity kind for the ROS graph publication endpoint.
pub const ROS_GRAPH_PUBLICATION_ENTITY_KIND : Byte = 0x03

///|
/// Standard user entity kind for the ROS graph subscription endpoint.
pub const ROS_GRAPH_SUBSCRIPTION_ENTITY_KIND : Byte = 0x04

///|
/// Validate an endpoint used for ROS graph discovery data.
pub fn validate_ros_discovery_info_endpoint(
  endpoint : @rtps.SedpEndpointData,
  kind : @rtps.SedpEndpointKind,
) -> Result[Unit, String] {
  if endpoint.kind() != kind {
    return Err("the ROS discovery endpoint has the wrong SEDP kind")
  }
  if endpoint.topic_name() != ROS_DISCOVERY_INFO_TOPIC_NAME ||
    endpoint.type_name() != ROS_DISCOVERY_INFO_TYPE_NAME {
    return Err("the endpoint is not ros_discovery_info")
  }
  let qos = match endpoint.qos() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if qos.reliability() != @rtps.RELIABILITY_RELIABLE {
    return Err("the ROS discovery endpoint is not reliable")
  }
  Ok(())
}

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
  endpoint.add_parameter(
    @rtps.qos_data_representation([@rtps.DATA_REPRESENTATION_XCDR1]),
  )
  match kind {
    Publication =>
      endpoint.add_parameter(@rtps.qos_history(@rtps.HISTORY_KEEP_LAST, 1))
    Subscription =>
      endpoint.add_parameter(@rtps.qos_history(@rtps.HISTORY_KEEP_ALL, 1))
  }
  endpoint.add_parameter(
    @rtps.qos_user_data_type_hash(ROS_DISCOVERY_INFO_TYPE_HASH),
  )
  Ok(endpoint)
}
