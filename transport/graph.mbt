///|
/// In-memory view of participants and SEDP endpoints seen during discovery.
pub struct DiscoveryGraph {
  participants : Array[@rtps.SpdpParticipantData]
  publications : Array[@rtps.SedpEndpointData]
  subscriptions : Array[@rtps.SedpEndpointData]
}

///|
pub fn DiscoveryGraph::new() -> DiscoveryGraph {
  { participants: [], publications: [], subscriptions: [], }
}

///|
/// Insert or replace one participant or endpoint discovery event.
pub fn DiscoveryGraph::ingest(
  self : DiscoveryGraph,
  event : DiscoveryEvent,
) -> Unit {
  match event {
    DiscoveryEvent::Participant(participant) => {
      for index in 0..<self.participants.length() {
        if self.participants[index].participant_guid() ==
          participant.participant_guid() {
          self.participants[index] = participant
          return
        }
      }
      self.participants.push(participant)
    }
    DiscoveryEvent::Publication(publication) => {
      for index in 0..<self.publications.length() {
        if self.publications[index].endpoint_guid() ==
          publication.endpoint_guid() {
          self.publications[index] = publication
          return
        }
      }
      self.publications.push(publication)
    }
    DiscoveryEvent::Subscription(subscription) => {
      for index in 0..<self.subscriptions.length() {
        if self.subscriptions[index].endpoint_guid() ==
          subscription.endpoint_guid() {
          self.subscriptions[index] = subscription
          return
        }
      }
      self.subscriptions.push(subscription)
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
pub fn DiscoveryGraph::participants(
  self : DiscoveryGraph,
) -> Array[@rtps.SpdpParticipantData] {
  self.participants
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
