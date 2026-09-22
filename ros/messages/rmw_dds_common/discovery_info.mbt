///|
/// The 16-byte ROS 2 graph-discovery GID.
pub struct Gid {
  data : Bytes
} derive(Eq, Debug)

///|
/// Create a ROS discovery GID.
pub fn Gid::new(data : Bytes) -> Result[Gid, String] {
  if data.length() != 16 {
    return Err("a ROS discovery GID must contain exactly 16 bytes")
  }
  Ok({ data, })
}

///|
/// Build a ROS discovery GID from an RTPS GUID.
pub fn Gid::from_guid(guid : @rtps.Guid) -> Gid {
  Gid::new(guid.to_bytes()).unwrap()
}

///|
/// Return the GID bytes.
pub fn Gid::data(self : Gid) -> Bytes {
  self.data
}

///|
/// ROS node metadata and its associated reader/writer GIDs.
pub struct NodeEntitiesInfo {
  node_namespace : String
  node_name : String
  reader_gid_seq : Array[Gid]
  writer_gid_seq : Array[Gid]
} derive(Eq, Debug)

///|
fn discovery_info_validate_string(
  value : String,
  label : String,
) -> Result[Unit, String] {
  if value.length() > 256 {
    Err("ROS discovery " + label + " exceeds 256 characters")
  } else {
    Ok(())
  }
}

///|
/// Create node entity information.
pub fn NodeEntitiesInfo::new(
  node_namespace : String,
  node_name : String,
) -> Result[NodeEntitiesInfo, String] {
  match discovery_info_validate_string(node_namespace, "namespace") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match discovery_info_validate_string(node_name, "name") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok({ node_namespace, node_name, reader_gid_seq: [], writer_gid_seq: [], })
}

///|
/// Return the node namespace.
pub fn NodeEntitiesInfo::node_namespace(self : NodeEntitiesInfo) -> String {
  self.node_namespace
}

///|
/// Return the node name.
pub fn NodeEntitiesInfo::node_name(self : NodeEntitiesInfo) -> String {
  self.node_name
}

///|
/// Return the reader GIDs.
pub fn NodeEntitiesInfo::reader_gid_seq(self : NodeEntitiesInfo) -> Array[Gid] {
  self.reader_gid_seq
}

///|
/// Return the writer GIDs.
pub fn NodeEntitiesInfo::writer_gid_seq(self : NodeEntitiesInfo) -> Array[Gid] {
  self.writer_gid_seq
}

///|
/// Add a reader GID.
pub fn NodeEntitiesInfo::add_reader_gid(
  self : NodeEntitiesInfo,
  gid : Gid,
) -> Unit {
  self.reader_gid_seq.push(gid)
}

///|
/// Add a writer GID.
pub fn NodeEntitiesInfo::add_writer_gid(
  self : NodeEntitiesInfo,
  gid : Gid,
) -> Unit {
  self.writer_gid_seq.push(gid)
}

///|
/// Participant metadata containing all nodes owned by the participant.
pub struct ParticipantEntitiesInfo {
  gid : Gid
  node_entities_info_seq : Array[NodeEntitiesInfo]
} derive(Eq, Debug)

///|
pub extend Gid with Eq::{not_equal, equal}

///|
pub extend Gid with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend NodeEntitiesInfo with Eq::{not_equal, equal}

///|
pub extend NodeEntitiesInfo with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ParticipantEntitiesInfo with Eq::{not_equal, equal}

///|
pub extend ParticipantEntitiesInfo with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Create participant entity information.
pub fn ParticipantEntitiesInfo::new(gid : Gid) -> ParticipantEntitiesInfo {
  { gid, node_entities_info_seq: [], }
}

///|
/// Return the participant GID.
pub fn ParticipantEntitiesInfo::gid(self : ParticipantEntitiesInfo) -> Gid {
  self.gid
}

///|
/// Return the participant's node information.
pub fn ParticipantEntitiesInfo::node_entities_info_seq(
  self : ParticipantEntitiesInfo,
) -> Array[NodeEntitiesInfo] {
  self.node_entities_info_seq
}

///|
/// Add node information to the participant.
pub fn ParticipantEntitiesInfo::add_node(
  self : ParticipantEntitiesInfo,
  node : NodeEntitiesInfo,
) -> Unit {
  self.node_entities_info_seq.push(node)
}

///|
fn discovery_info_write_gid(writer : @cdr.Writer, gid : Gid) -> Unit {
  writer.write_byte_array(gid.data)
}

///|
fn discovery_info_read_gid(reader : @cdr.Reader) -> Result[Gid, String] {
  let data = match reader.read_byte_array(16) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Gid::new(data)
}

///|
fn discovery_info_write_gid_sequence(
  writer : @cdr.Writer,
  gids : Array[Gid],
) -> Unit {
  writer.write_u32(gids.length().reinterpret_as_uint())
  for gid in gids {
    discovery_info_write_gid(writer, gid)
  }
}

///|
fn discovery_info_read_gid_sequence(
  reader : @cdr.Reader,
) -> Result[Array[Gid], String] {
  let length = match reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if length < 0 || length > reader.remaining() / 16 {
    return Err("a ROS discovery GID sequence is truncated")
  }
  let result : Array[Gid] = []
  for _ in 0..<length {
    result.push(
      match discovery_info_read_gid(reader) {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
  }
  Ok(result)
}

///|
fn discovery_info_write_node(
  writer : @cdr.Writer,
  node : NodeEntitiesInfo,
) -> Unit {
  writer.write_string(node.node_namespace)
  writer.write_string(node.node_name)
  discovery_info_write_gid_sequence(writer, node.reader_gid_seq)
  discovery_info_write_gid_sequence(writer, node.writer_gid_seq)
}

///|
fn discovery_info_read_node(
  reader : @cdr.Reader,
) -> Result[NodeEntitiesInfo, String] {
  let node_namespace = match reader.read_string() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let node_name = match reader.read_string() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let reader_gid_seq = match discovery_info_read_gid_sequence(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let writer_gid_seq = match discovery_info_read_gid_sequence(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let node = match NodeEntitiesInfo::new(node_namespace, node_name) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  for gid in reader_gid_seq {
    node.reader_gid_seq.push(gid)
  }
  for gid in writer_gid_seq {
    node.writer_gid_seq.push(gid)
  }
  Ok(node)
}

///|
/// Serialize `NodeEntitiesInfo` as CDR little-endian.
pub fn NodeEntitiesInfo::to_cdr_bytes(self : NodeEntitiesInfo) -> Bytes {
  let writer = @cdr.Writer::new()
  discovery_info_write_node(writer, self)
  writer.to_bytes()
}

///|
/// Parse `NodeEntitiesInfo` from CDR little-endian.
pub fn NodeEntitiesInfo::from_cdr_bytes(
  input : Bytes,
) -> Result[NodeEntitiesInfo, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let node = match discovery_info_read_node(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if !reader.remaining_is_zero_padding(4) {
    return Err("trailing bytes after ROS NodeEntitiesInfo")
  }
  Ok(node)
}

///|
/// Serialize `ParticipantEntitiesInfo` as CDR little-endian.
pub fn ParticipantEntitiesInfo::to_cdr_bytes(
  self : ParticipantEntitiesInfo,
) -> Bytes {
  let writer = @cdr.Writer::new()
  discovery_info_write_gid(writer, self.gid)
  writer.write_u32(self.node_entities_info_seq.length().reinterpret_as_uint())
  for node in self.node_entities_info_seq {
    discovery_info_write_node(writer, node)
  }
  writer.to_bytes()
}

///|
/// Parse `ParticipantEntitiesInfo` from CDR little-endian.
pub fn ParticipantEntitiesInfo::from_cdr_bytes(
  input : Bytes,
) -> Result[ParticipantEntitiesInfo, String] {
  let reader = match @cdr.Reader::from_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let gid = match discovery_info_read_gid(reader) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let length = match reader.read_u32() {
    Ok(value) => value.reinterpret_as_int()
    Err(message) => return Err(message)
  }
  if length < 0 || length > reader.remaining() {
    return Err("a ROS discovery node sequence is truncated")
  }
  let result = ParticipantEntitiesInfo::new(gid)
  for _ in 0..<length {
    result.node_entities_info_seq.push(
      match discovery_info_read_node(reader) {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
  }
  if !reader.remaining_is_zero_padding(4) {
    return Err("trailing bytes after ROS ParticipantEntitiesInfo")
  }
  Ok(result)
}
