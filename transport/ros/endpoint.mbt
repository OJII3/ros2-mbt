///|
/// Whether a discovered writer can be reached over the UDP/IPv4 transport.
fn ros_endpoint_has_udp_v4_locator(endpoint : @rtps.SedpEndpointData) -> Bool {
  let locators = if endpoint.unicast_locators().length() > 0 {
    endpoint.unicast_locators()
  } else {
    endpoint.multicast_locators()
  }
  for locator in locators {
    if locator.kind() == @rtps.LOCATOR_KIND_UDP_V4 {
      return true
    }
  }
  false
}
