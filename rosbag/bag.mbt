///|
/// A ROS 2 MCAP bag, made of one or more MCAP files in playback order.
pub struct BagRecording {
  priv files : Array[BagRecordingFile]
  priv topics : Array[BagTopic]
  priv first_log_time_ns : UInt64?
}

///|
priv struct BagRecordingFile {
  path : String
  catalog : BagCatalog
}

///|
/// The parts of a rosbag2 metadata.yaml that determine what to play.
priv struct BagMetadata {
  storage_identifier : String
  compression_mode : String
  relative_file_paths : Array[String]
}

///|
/// Scan a ROS 2 bag from a bag directory or a single MCAP file.
///
/// A bag directory must contain metadata.yaml. Its relative file paths are
/// played in the listed order. A path to one MCAP file is scanned directly.
pub async fn scan_bag(path : String) -> Result[BagRecording, String] {
  let paths = match bag_file_paths(path) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let files : Array[BagRecordingFile] = []
  let topics : Array[BagTopic] = []
  let mut first_log_time_ns : UInt64? = None
  for file_path in paths {
    let catalog = match scan_bag_file(file_path) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    if first_log_time_ns is None {
      first_log_time_ns = catalog.first_log_time_ns
    }
    match merge_bag_topics(topics, catalog.topics) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    files.push({ path: file_path, catalog, })
  }
  Ok({ files, topics, first_log_time_ns, })
}

///|
async fn scan_bag_file(path : String) -> Result[BagCatalog, String] {
  let file = @fs.open(path, mode=ReadOnly) catch {
    _ => return Err("could not open MCAP file: " + path)
  }
  defer file.close()
  let reader = match @mcap.Reader::new(file) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  scan_mcap_catalog(reader)
}

///|
async fn bag_file_paths(path : String) -> Result[Array[String], String] {
  let kind = @fs.kind(path) catch {
    _ => return Err("could not access bag path: " + path)
  }
  match kind {
    Directory => bag_directory_files(path)
    _ => Ok([path])
  }
}

///|
async fn bag_directory_files(
  directory : String,
) -> Result[Array[String], String] {
  let metadata_path = join_bag_path(directory, "metadata.yaml")
  let metadata_text = @fs.read_text(metadata_path) catch {
    _ =>
      return Err(
        "bag directory does not contain a readable metadata.yaml: " + directory,
      )
  }
  let metadata = match parse_bag_metadata(metadata_text) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if metadata.storage_identifier != "mcap" {
    return Err("bag storage is not MCAP: " + metadata.storage_identifier)
  }
  if metadata.compression_mode.length() > 0 {
    return Err("rosbag2-compressed bags are not supported: " + directory)
  }
  if metadata.relative_file_paths.length() == 0 {
    return Err("metadata.yaml lists no bag files: " + directory)
  }
  Ok(
    metadata.relative_file_paths.map(fn(path) { join_bag_path(directory, path) }),
  )
}

///|
fn join_bag_path(directory : String, relative : String) -> String {
  if directory.has_suffix("/") {
    directory + relative
  } else {
    directory + "/" + relative
  }
}

///|
/// Read the playback-relevant fields from a rosbag2 metadata.yaml.
fn parse_bag_metadata(text : String) -> Result[BagMetadata, String] {
  let mut storage_identifier = ""
  let mut compression_mode = ""
  let relative_file_paths : Array[String] = []
  let mut list_indent = -1
  for raw_line in text.split("\n") {
    let line = raw_line.to_owned()
    let trimmed = line.trim(chars=" \t\r")
    if trimmed.length() == 0 || trimmed.has_prefix("#") {
      continue
    }
    let indent = leading_space_count(line)
    if list_indent >= 0 {
      if indent > list_indent && trimmed.has_prefix("-") {
        let item = trimmed.after("-").unwrap().trim(chars=" \t\r")
        let path = decode_yaml_scalar(item)
        if path.length() == 0 {
          return Err("metadata.yaml contains an empty file path")
        }
        relative_file_paths.push(path)
        continue
      }
      if indent <= list_indent {
        list_indent = -1
      }
    }
    if trimmed.has_prefix("storage_identifier:") {
      storage_identifier = decode_yaml_scalar(
        trimmed.after("storage_identifier:").unwrap(),
      )
    } else if trimmed.has_prefix("compression_mode:") {
      compression_mode = decode_yaml_scalar(
        trimmed.after("compression_mode:").unwrap(),
      )
    } else if trimmed.has_prefix("relative_file_paths:") {
      let inline = trimmed
        .after("relative_file_paths:")
        .unwrap()
        .trim(chars=" \t\r")
      if inline.length() > 0 {
        return Err(
          "metadata.yaml relative_file_paths must use a block sequence",
        )
      }
      list_indent = indent
    }
  }
  if storage_identifier.length() == 0 {
    return Err("metadata.yaml does not declare storage_identifier")
  }
  Ok({ storage_identifier, compression_mode, relative_file_paths, })
}

///|
fn leading_space_count(line : StringView) -> Int32 {
  let mut count = 0
  while line.get_char(count) == Some(' ') {
    count += 1
  }
  count
}

///|
fn decode_yaml_scalar(value : StringView) -> String {
  let value = value.trim(chars=" \t\r")
  if value.length() >= 2 && value.has_prefix("'") && value.has_suffix("'") {
    return value
      .exact_view(start=1, end=value.length() - 1)
      .replace_all(old="''", new="'")
      .to_owned()
  }
  if value.length() >= 2 && value.has_prefix("\"") && value.has_suffix("\"") {
    return value
      .exact_view(start=1, end=value.length() - 1)
      .replace_all(old="\\\"", new="\"")
      .replace_all(old="\\\\", new="\\")
      .to_owned()
  }
  value.to_owned()
}

///|
fn merge_bag_topics(
  topics : Array[BagTopic],
  incoming : Array[BagTopic],
) -> Result[Unit, String] {
  for topic in incoming {
    match bag_topic_index(topics, topic.name) {
      Some(index) => {
        if topics[index].type_name != topic.type_name {
          return Err("ROS topic has more than one message type: " + topic.name)
        }
        let type_hash = topic.type_hash
        if type_hash.length() > 0 {
          let existing_hash = topics[index].type_hash
          if existing_hash.length() > 0 && existing_hash != type_hash {
            return Err("ROS topic has conflicting type hashes: " + topic.name)
          }
          if existing_hash.length() == 0 {
            topics[index] = { ..topics[index], type_hash, }
          }
        }
        for qos_profile in topic.qos_profiles {
          let qos_profiles = topics[index].qos_profiles
          if !qos_profiles.contains(qos_profile) {
            qos_profiles.push(qos_profile)
          }
        }
      }
      None => topics.push(topic)
    }
  }
  Ok(())
}

///|
/// Return the topics contained in this recording.
pub fn BagRecording::topics(self : BagRecording) -> Array[BagTopic] {
  self.topics.copy()
}

///|
/// Return catalog topics selected by name, or all topics when the list is empty.
pub fn BagRecording::select_topics(
  self : BagRecording,
  requested : Array[String],
) -> Result[Array[BagTopic], String] {
  if requested.length() == 0 {
    return Ok(self.topics())
  }
  let selected : Array[BagTopic] = []
  for name in requested {
    let topic = match bag_topic_by_name(self.topics, name) {
      Some(value) => value
      None => return Err("topic is not present in the bag: " + name)
    }
    if !contains_topic_name(selected, name) {
      selected.push(topic)
    }
  }
  Ok(selected)
}

///|
fn bag_topic_by_name(topics : Array[BagTopic], name : String) -> BagTopic? {
  for topic in topics {
    if topic.name == name {
      return Some(topic)
    }
  }
  None
}

///|
fn contains_topic_name(topics : Array[BagTopic], name : String) -> Bool {
  for topic in topics {
    if topic.name == name {
      return true
    }
  }
  false
}
