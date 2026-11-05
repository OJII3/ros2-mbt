///|
/// In-memory view of participants and SEDP endpoints seen during discovery.
pub struct DiscoveryGraph {
  mut participants : Array[@rtps.SpdpParticipantData]
  mut publications : Array[@rtps.SedpEndpointData]
  mut subscriptions : Array[@rtps.SedpEndpointData]
  mut ros_participants : Array[@ros.ParticipantEntitiesInfo]
}

///|
/// Remove one endpoint GID from all retained ROS graph snapshots.
fn DiscoveryGraph::remove_ros_endpoint(
  self : DiscoveryGraph,
  endpoint_guid : @rtps.Guid,
) -> Unit {
  let endpoint_gid = @ros.Gid::from_guid(endpoint_guid)
  let remaining : Array[@ros.ParticipantEntitiesInfo] = []
  for info in self.ros_participants {
    let updated = @ros.ParticipantEntitiesInfo::new(info.gid())
    for node in info.node_entities_info_seq() {
      let updated_node = @ros.NodeEntitiesInfo::new(
        node.node_namespace(),
        node.node_name(),
      ).unwrap()
      for gid in node.reader_gid_seq() {
        if gid != endpoint_gid {
          updated_node.add_reader_gid(gid)
        }
      }
      for gid in node.writer_gid_seq() {
        if gid != endpoint_gid {
          updated_node.add_writer_gid(gid)
        }
      }
      updated.add_node(updated_node)
    }
    remaining.push(updated)
  }
  self.ros_participants = remaining
}

///|
/// Create an empty discovery graph.
pub fn DiscoveryGraph::new() -> DiscoveryGraph {
  {
    participants: [],
    publications: [],
    subscriptions: [],
    ros_participants: [],
  }
}

///|
/// Insert or replace one participant or endpoint discovery event.
pub fn DiscoveryGraph::ingest(
  self : DiscoveryGraph,
  event : @wire.DiscoveryEvent,
) -> Unit {
  match event {
    Participant(participant) =>
      match
        self.participants.search_by(fn(existing) {
          existing.participant_guid() == participant.participant_guid()
        }) {
        Some(index) => self.participants[index] = participant
        None => self.participants.push(participant)
      }
    Publication(publication) =>
      match
        self.publications.search_by(fn(existing) {
          existing.endpoint_guid() == publication.endpoint_guid()
        }) {
        Some(index) => self.publications[index] = publication
        None => self.publications.push(publication)
      }
    Subscription(subscription) =>
      match
        self.subscriptions.search_by(fn(existing) {
          existing.endpoint_guid() == subscription.endpoint_guid()
        }) {
        Some(index) => self.subscriptions[index] = subscription
        None => self.subscriptions.push(subscription)
      }
    EndpointRemoved(kind, endpoint_guid) => {
      match kind {
        Publication =>
          self.publications = self.publications.filter(fn(publication) {
            publication.endpoint_guid() != endpoint_guid
          })
        Subscription =>
          self.subscriptions = self.subscriptions.filter(fn(subscription) {
            subscription.endpoint_guid() != endpoint_guid
          })
      }
      self.remove_ros_endpoint(endpoint_guid)
    }
    ParticipantRemoved(participant_guid) => {
      self.participants = self.participants.filter(fn(participant) {
        participant.participant_guid() != participant_guid
      })
      self.publications = self.publications.filter(fn(publication) {
        publication.endpoint_guid().prefix() != participant_guid.prefix()
      })
      self.subscriptions = self.subscriptions.filter(fn(subscription) {
        subscription.endpoint_guid().prefix() != participant_guid.prefix()
      })
      let participant_gid = @ros.Gid::from_guid(participant_guid)
      self.ros_participants = self.ros_participants.filter(fn(info) {
        info.gid() != participant_gid
      })
    }
  }
}

///|
/// Return the number of discovered participants.
pub fn DiscoveryGraph::participant_count(self : DiscoveryGraph) -> Int32 {
  self.participants.length()
}

///|
/// Return the number of discovered publications.
pub fn DiscoveryGraph::publication_count(self : DiscoveryGraph) -> Int32 {
  self.publications.length()
}

///|
/// Return the number of discovered subscriptions.
pub fn DiscoveryGraph::subscription_count(self : DiscoveryGraph) -> Int32 {
  self.subscriptions.length()
}

///|
/// Insert or replace one ROS graph-discovery sample by participant GID.
pub fn DiscoveryGraph::ingest_ros_discovery_info(
  self : DiscoveryGraph,
  info : @ros.ParticipantEntitiesInfo,
) -> Unit {
  match
    self.ros_participants.search_by(fn(existing) {
      existing.gid() == info.gid()
    }) {
    Some(index) => self.ros_participants[index] = info
    None => self.ros_participants.push(info)
  }
}

///|
/// Return the number of ROS graph participants.
pub fn DiscoveryGraph::ros_participant_count(self : DiscoveryGraph) -> Int32 {
  self.ros_participants.length()
}

///|
/// Return the retained ROS graph participant information.
pub fn DiscoveryGraph::ros_participants(
  self : DiscoveryGraph,
) -> Array[@ros.ParticipantEntitiesInfo] {
  self.ros_participants
}

///|
/// Return the discovered participants.
pub fn DiscoveryGraph::participants(
  self : DiscoveryGraph,
) -> Array[@rtps.SpdpParticipantData] {
  self.participants
}

///|
/// Return the vendor ID of the participant owning an endpoint GUID prefix.
pub fn DiscoveryGraph::participant_vendor_id(
  self : DiscoveryGraph,
  participant_guid : @rtps.Guid,
) -> @rtps.VendorId? {
  for participant in self.participants {
    if participant.participant_guid().prefix() == participant_guid.prefix() {
      return Some(participant.vendor_id())
    }
  }
  None
}

///|
/// Return the discovered publications.
pub fn DiscoveryGraph::publications(
  self : DiscoveryGraph,
) -> Array[@rtps.SedpEndpointData] {
  self.publications
}

///|
/// Return the discovered subscriptions.
pub fn DiscoveryGraph::subscriptions(
  self : DiscoveryGraph,
) -> Array[@rtps.SedpEndpointData] {
  self.subscriptions
}

///|
/// Return all discovered publications matching a DDS topic/type identity.
pub fn DiscoveryGraph::find_publications(
  self : DiscoveryGraph,
  topic_name : String,
  type_name : String,
) -> Array[@rtps.SedpEndpointData] {
  let result : Array[@rtps.SedpEndpointData] = []
  for publication in self.publications {
    if publication.topic_name() == topic_name &&
      publication.type_name() == type_name {
      result.push(publication)
    }
  }
  result
}

///|
/// Return all discovered subscriptions matching a DDS topic/type identity.
pub fn DiscoveryGraph::find_subscriptions(
  self : DiscoveryGraph,
  topic_name : String,
  type_name : String,
) -> Array[@rtps.SedpEndpointData] {
  let result : Array[@rtps.SedpEndpointData] = []
  for subscription in self.subscriptions {
    if subscription.topic_name() == topic_name &&
      subscription.type_name() == type_name {
      result.push(subscription)
    }
  }
  result
}

///|
/// Return publications matching a subscription's topic, type, and basic QoS.
pub fn DiscoveryGraph::find_compatible_publications(
  self : DiscoveryGraph,
  subscription : @rtps.SedpEndpointData,
) -> Result[Array[@rtps.SedpEndpointData], String] {
  let result : Array[@rtps.SedpEndpointData] = []
  for publication in self.publications {
    if publication.topic_name() != subscription.topic_name() ||
      publication.type_name() != subscription.type_name() {
      continue
    }
    let compatible = match publication.qos_compatible_with(subscription) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    if compatible {
      result.push(publication)
    }
  }
  Ok(result)
}
