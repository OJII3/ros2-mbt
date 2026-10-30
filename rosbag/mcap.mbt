///|
priv struct SchemaInfo {
  id : UInt16
  name : String
  encoding : String
  data : Bytes
}

///|
priv struct ChannelRoute {
  id : UInt16
  topic_name : String
  schema_id : UInt16
  message_encoding : String
  metadata : Array[(String, String)]
}

///|
/// ROS topic information read from a ROS 2 MCAP Channel and Schema.
pub struct BagTopic {
  priv name : String
  priv type_name : String
  priv type_hash : String
  priv qos_profiles : Array[String]
}

///|
/// Catalog of all ROS 2 topics in an MCAP file.
pub struct BagCatalog {
  priv topics : Array[BagTopic]
  priv routes : Array[ChannelRoute]
}

///|
/// One opaque CDR payload and its recorded log time.
pub struct BagMessage {
  priv topic_name : String
  priv log_time_ns : UInt64
  priv payload : Bytes
}

///|
/// Scan a ROS 2 MCAP stream and validate its channel and schema references.
/// This pass retains topic metadata only, not message payloads.
pub async fn scan_mcap_catalog(
  reader : @mcap.Reader,
) -> Result[BagCatalog, String] {
  if reader.profile() != "ros2" {
    return Err("MCAP profile must be ros2")
  }
  let schemas : Array[SchemaInfo] = []
  let channels : Array[ChannelRoute] = []
  let topics : Array[BagTopic] = []
  while true {
    let record = match reader.next_record() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    match record {
      None => return Ok({ topics, routes: channels, })
      Some(@mcap.Record::Schema(id, name, encoding, data)) => {
        if id == 0U.to_uint16() {
          continue
        }
        match schema_info_by_id(schemas, id) {
          Some(existing) if existing.name != name ||
            existing.encoding != encoding ||
            existing.data != data =>
            return Err("MCAP schema ID is reused with different contents")
          Some(_) => ()
          None => schemas.push({ id, name, encoding, data, })
        }
      }
      Some(
        @mcap.Record::Channel(
          id,
          schema_id,
          topic_name,
          message_encoding,
          metadata
        )
      ) => {
        if message_encoding != "cdr" {
          return Err(
            "ROS 2 MCAP channel " +
            topic_name +
            " uses unsupported encoding: " +
            message_encoding,
          )
        }
        let schema = match schema_info_by_id(schemas, schema_id) {
          Some(value) => value
          None => return Err("MCAP channel references a missing schema")
        }
        if schema.encoding != "ros2msg" && schema.encoding != "ros2idl" {
          return Err(
            "ROS 2 MCAP schema uses unsupported encoding: " + schema.encoding,
          )
        }
        if !valid_ros_message_type(schema.name) {
          return Err("invalid ROS 2 message type name in MCAP: " + schema.name)
        }
        match channel_route_by_id(channels, id) {
          Some(route) if route.topic_name != topic_name ||
            route.schema_id != schema_id ||
            route.message_encoding != message_encoding ||
            !metadata_equal(route.metadata, metadata) =>
            return Err("MCAP channel ID is reused with different contents")
          Some(_) => ()
          None => {
            channels.push({
              id,
              topic_name,
              schema_id,
              message_encoding,
              metadata,
            })
            let type_hash = metadata_value(metadata, "topic_type_hash")
            let qos_profile = metadata_value(metadata, "offered_qos_profiles")
            match bag_topic_index(topics, topic_name) {
              Some(index) => {
                if topics[index].type_name != schema.name {
                  return Err(
                    "ROS topic has more than one message type: " + topic_name,
                  )
                }
                if type_hash.length() > 0 {
                  let existing_hash = topics[index].type_hash
                  if existing_hash.length() > 0 && existing_hash != type_hash {
                    return Err(
                      "ROS topic has conflicting type hashes: " + topic_name,
                    )
                  }
                  if existing_hash.length() == 0 {
                    topics[index] = { ..topics[index], type_hash, }
                  }
                }
                if qos_profile.length() > 0 &&
                  !contains_string(topics[index].qos_profiles, qos_profile) {
                  let qos_profiles = topics[index].qos_profiles
                  qos_profiles.push(qos_profile)
                }
              }
              None => {
                let qos_profiles = if qos_profile.length() > 0 {
                  [qos_profile]
                } else {
                  []
                }
                topics.push({
                  name: topic_name,
                  type_name: schema.name,
                  type_hash,
                  qos_profiles,
                })
              }
            }
          }
        }
      }
      Some(@mcap.Record::Message(channel_id, _, _, _, _)) =>
        if channel_route_by_id(channels, channel_id) is None {
          return Err("MCAP message references an unknown channel")
        }
      Some(@mcap.Record::Metadata(name, metadata)) if name == "rosbag2" => {
        let serialized_metadata = metadata_value(
          metadata, "serialized_metadata",
        )
        if serialized_metadata.contains("compression_mode: MESSAGE") {
          return Err("rosbag2 message-compressed MCAP files are not supported")
        }
      }
      Some(@mcap.Record::Metadata(_, _)) => ()
      Some(@mcap.Record::DataEnd) => return Ok({ topics, routes: channels, })
    }
  } nobreak {
    Err("MCAP catalog scan stopped unexpectedly")
  }
}

///|
fn schema_info_by_id(schemas : Array[SchemaInfo], id : UInt16) -> SchemaInfo? {
  for schema in schemas {
    if schema.id == id {
      return Some(schema)
    }
  }
  None
}

///|
fn metadata_equal(
  left : Array[(String, String)],
  right : Array[(String, String)],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index in 0..<left.length() {
    if left[index] != right[index] {
      return false
    }
  }
  true
}

///|
fn channel_route_by_id(
  channels : Array[ChannelRoute],
  id : UInt16,
) -> ChannelRoute? {
  for channel in channels {
    if channel.id == id {
      return Some(channel)
    }
  }
  None
}

///|
fn bag_topic_index(topics : Array[BagTopic], name : String) -> Int32? {
  for index in 0..<topics.length() {
    if topics[index].name == name {
      return Some(index)
    }
  }
  None
}

///|
fn metadata_value(metadata : Array[(String, String)], key : String) -> String {
  for (candidate, value) in metadata {
    if candidate == key {
      return value
    }
  }
  ""
}

///|
fn contains_string(values : Array[String], target : String) -> Bool {
  for value in values {
    if value == target {
      return true
    }
  }
  false
}

///|
fn valid_ros_message_type(type_name : String) -> Bool {
  let parts = type_name.split("/").collect()
  parts.length() == 3 &&
  parts[1] == "msg" &&
  parts[0].length() > 0 &&
  parts[2].length() > 0
}

///|
/// Stream messages from an MCAP file using a previously scanned catalog.
pub struct McapMessageSource {
  priv reader : @mcap.Reader
  priv catalog : BagCatalog
}

///|
pub fn McapMessageSource::new(
  reader : @mcap.Reader,
  catalog : BagCatalog,
) -> Result[McapMessageSource, String] {
  if reader.profile() != "ros2" {
    return Err("MCAP profile must be ros2")
  }
  Ok({ reader, catalog, })
}

///|
/// Return the next message in file order.
pub async fn McapMessageSource::next(
  self : McapMessageSource,
) -> Result[BagMessage?, String] {
  while true {
    let record = match self.reader.next_record() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    match record {
      None => return Ok(None)
      Some(@mcap.Record::Message(channel_id, _, log_time_ns, _, payload)) => {
        let route = match channel_route_by_id(self.catalog.routes, channel_id) {
          Some(value) => value
          None => return Err("MCAP message references an unknown channel")
        }
        return Ok(Some({ topic_name: route.topic_name, log_time_ns, payload, }))
      }
      Some(@mcap.Record::DataEnd) => return Ok(None)
      Some(@mcap.Record::Schema(_, _, _, _))
      | Some(@mcap.Record::Channel(_, _, _, _, _)) => ()
      Some(@mcap.Record::Metadata(_, _)) => ()
    }
  } nobreak {
    Err("MCAP message stream stopped unexpectedly")
  }
}

///|
/// Return the topics contained in this catalog.
pub fn BagCatalog::topics(self : BagCatalog) -> Array[BagTopic] {
  let topics : Array[BagTopic] = []
  for topic in self.topics {
    topics.push(topic)
  }
  topics
}

///|
/// Return the ROS topic name.
pub fn BagTopic::name(self : BagTopic) -> String {
  self.name
}

///|
/// Return the ROS message type path such as `std_msgs/msg/String`.
pub fn BagTopic::type_name(self : BagTopic) -> String {
  self.type_name
}

///|
/// Return the RIHS01 type hash when the recording provided one.
pub fn BagTopic::type_hash(self : BagTopic) -> String {
  self.type_hash
}

///|
/// Return recorded QoS profiles as their original YAML strings.
pub fn BagTopic::qos_profiles(self : BagTopic) -> Array[String] {
  let profiles : Array[String] = []
  for profile in self.qos_profiles {
    profiles.push(profile)
  }
  profiles
}

///|
/// Return the ROS topic name of a recorded message.
pub fn BagMessage::topic_name(self : BagMessage) -> String {
  self.topic_name
}

///|
/// Return the recording log timestamp in nanoseconds.
pub fn BagMessage::log_time_ns(self : BagMessage) -> UInt64 {
  self.log_time_ns
}

///|
/// Return the raw serialized CDR payload.
pub fn BagMessage::payload(self : BagMessage) -> Bytes {
  self.payload
}
