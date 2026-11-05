///|
/// Create a ROS node with a fresh DDSI-RTPS participant.
///
/// Participant IDs must be unique among participants on the same host and
/// domain. The node uses vendor ID 0x010F and a 60-second participant lease.
pub async fn RosNode::new_ddsi(
  node_namespace : String,
  node_name : String,
  domain_id~ : UInt32 = 0U,
  participant_id~ : UInt32 = 0U,
  ip~ : UInt32 = 0x7F000001U,
  multicast_interface? : UInt32,
) -> Result[RosNode, String] {
  let vendor_id = @rtps.VendorId::new(1, 15)
  guard @env.rand(12) is Some(random) else {
    return Err("secure randomness is unavailable for a DDS GUID prefix")
  }
  let prefix_bytes = random.to_array()
  prefix_bytes[0] = 1
  prefix_bytes[1] = 15
  let guid_prefix = match @rtps.GuidPrefix::from_array(prefix_bytes) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let multicast_interface = multicast_interface.unwrap_or(ip)
  let participant = match
    RosParticipant::new_ddsi(
      guid_prefix,
      vendor_id,
      domain_id,
      participant_id,
      ip,
      60,
      1L,
      multicast_interface~,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  RosNode::new(participant, node_namespace, node_name)
}
