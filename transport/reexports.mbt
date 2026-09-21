///|
/// Re-export the transport packages through the original `transport` API.
pub using @wire {
  DDSI_DEFAULT_MULTICAST_IP,
  DDSI_DOMAIN_ID_GAIN,
  DDSI_PARTICIPANT_ID_GAIN,
  DDSI_PORT_BASE,
  DDSI_SPDP_MULTICAST_OFFSET,
  DDSI_SPDP_UNICAST_OFFSET,
  DDSI_USER_MULTICAST_OFFSET,
  DDSI_USER_UNICAST_OFFSET,
  MAX_DATAGRAM_SIZE,
  ddsi_default_spdp_multicast_addr,
  ddsi_default_spdp_unicast_addr,
  ddsi_default_user_multicast_addr,
  ddsi_default_user_unicast_addr,
  ddsi_spdp_multicast_port,
  ddsi_spdp_unicast_port,
  ddsi_user_multicast_port,
  ddsi_user_unicast_port,
  new_ddsi_participant,
  type DataReader,
  type DataWriter,
  type DiscoveryEvent,
  type ReliableDataReader,
  type ReliableDataReaderSession,
  type ReliableDataWriter,
  type ReliableSedpWriter,
  type Udp,
}

///|
pub using @discovery {
  type DiscoveryGraph,
  type DiscoveryService,
  type DiscoverySession,
}

///|
pub using @ros_transport {
  type ReliableRosDiscoveryPublisher,
  type ReliableRosDiscoverySubscription,
  type ReliableRosPublisher,
  type ReliableRosSubscription,
  type RosActionClient,
  type RosActionEndpoints,
  type RosActionGoalHandle,
  type RosParticipant,
  type RosPublisher,
  type RosServiceClient,
  type RosServiceServer,
  type RosServiceWireFormat,
  type RosSubscription,
}
