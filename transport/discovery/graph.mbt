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
    Participant(participant) => {
      for index in 0..<self.participants.length() {
        if self.participants[index].participant_guid() ==
          participant.participant_guid() {
          self.participants[index] = participant
          return
        }
      }
      self.participants.push(participant)
    }
    Publication(publication) => {
      for index in 0..<self.publications.length() {
        if self.publications[index].endpoint_guid() ==
          publication.endpoint_guid() {
          self.publications[index] = publication
          return
        }
      }
      self.publications.push(publication)
    }
    Subscription(subscription) => {
      for index in 0..<self.subscriptions.length() {
        if self.subscriptions[index].endpoint_guid() ==
          subscription.endpoint_guid() {
          self.subscriptions[index] = subscription
          return
        }
      }
      self.subscriptions.push(subscription)
    }
    EndpointRemoved(kind, endpoint_guid) => {
      match kind {
        Publication => {
          let remaining : Array[@rtps.SedpEndpointData] = []
          for publication in self.publications {
            if publication.endpoint_guid() != endpoint_guid {
              remaining.push(publication)
            }
          }
          self.publications = remaining
        }
        Subscription => {
          let remaining : Array[@rtps.SedpEndpointData] = []
          for subscription in self.subscriptions {
            if subscription.endpoint_guid() != endpoint_guid {
              remaining.push(subscription)
            }
          }
          self.subscriptions = remaining
        }
      }
      self.remove_ros_endpoint(endpoint_guid)
    }
    ParticipantRemoved(participant_guid) => {
      let remaining_participants : Array[@rtps.SpdpParticipantData] = []
      for participant in self.participants {
        if participant.participant_guid() != participant_guid {
          remaining_participants.push(participant)
        }
      }
      self.participants = remaining_participants
      let remaining_publications : Array[@rtps.SedpEndpointData] = []
      for publication in self.publications {
        if publication.endpoint_guid().prefix() != participant_guid.prefix() {
          remaining_publications.push(publication)
        }
      }
      self.publications = remaining_publications
      let remaining_subscriptions : Array[@rtps.SedpEndpointData] = []
      for subscription in self.subscriptions {
        if subscription.endpoint_guid().prefix() != participant_guid.prefix() {
          remaining_subscriptions.push(subscription)
        }
      }
      self.subscriptions = remaining_subscriptions
      let participant_gid = @ros.Gid::from_guid(participant_guid)
      let remaining_ros_participants : Array[@ros.ParticipantEntitiesInfo] = []
      for info in self.ros_participants {
        if info.gid() != participant_gid {
          remaining_ros_participants.push(info)
        }
      }
      self.ros_participants = remaining_ros_participants
    }
  }
}

///|
pub fn DiscoveryGraph::participant_count(self : DiscoveryGraph) -> Int {
  self.participants.length()
}

///|
pub fn DiscoveryGraph::publication_count(self : DiscoveryGraph) -> Int {
  self.publications.length()
}

///|
pub fn DiscoveryGraph::subscription_count(self : DiscoveryGraph) -> Int {
  self.subscriptions.length()
}

///|
/// Insert or replace one ROS graph-discovery sample by participant GID.
pub fn DiscoveryGraph::ingest_ros_discovery_info(
  self : DiscoveryGraph,
  info : @ros.ParticipantEntitiesInfo,
) -> Unit {
  for index in 0..<self.ros_participants.length() {
    if self.ros_participants[index].gid() == info.gid() {
      self.ros_participants[index] = info
      return
    }
  }
  self.ros_participants.push(info)
}

///|
pub fn DiscoveryGraph::ros_participant_count(self : DiscoveryGraph) -> Int {
  self.ros_participants.length()
}

///|
pub fn DiscoveryGraph::ros_participants(
  self : DiscoveryGraph,
) -> Array[@ros.ParticipantEntitiesInfo] {
  self.ros_participants
}

///|
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
pub fn DiscoveryGraph::publications(
  self : DiscoveryGraph,
) -> Array[@rtps.SedpEndpointData] {
  self.publications
}

///|
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
