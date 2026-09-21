///|
/// The four-byte entity identifier within an RTPS GUID.
pub struct EntityId {
  key : Bytes
  kind : Byte
} derive(Eq, Debug)

///|
/// A complete RTPS GUID.
pub struct Guid {
  prefix : GuidPrefix
  entity_id : EntityId
} derive(Eq, Debug)

///|
/// Create an entity identifier from its three-byte key and kind byte.
pub fn EntityId::new(key : Bytes, kind : Byte) -> Result[EntityId, String] {
  if key.length() != 3 {
    Err("an RTPS entity key must contain exactly 3 bytes")
  } else {
    Ok({ key, kind, })
  }
}

///|
/// Return the RTPS wildcard entity ID used by multicast HEARTBEAT messages.
pub fn EntityId::unknown() -> EntityId {
  EntityId::new(b"\x00\x00\x00", 0).unwrap()
}

///|
/// Return the three-byte entity key.
pub fn EntityId::key(self : EntityId) -> Bytes {
  self.key
}

///|
/// Return the entity kind byte.
pub fn EntityId::kind(self : EntityId) -> Byte {
  self.kind
}

///|
/// Serialize an entity identifier.
pub fn EntityId::to_bytes(self : EntityId) -> Bytes {
  let bytes : Array[Byte] = []
  for i in 0..<3 {
    bytes.push(self.key[i])
  }
  bytes.push(self.kind)
  Bytes::from_array(bytes)
}

///|
/// Parse an entity identifier.
pub fn EntityId::from_bytes(input : Bytes) -> Result[EntityId, String] {
  if input.length() != 4 {
    return Err("an RTPS entity identifier is 4 bytes")
  }
  EntityId::new(bytes_from(input, 0, 3), input[3])
}

///|
/// Create a GUID from a participant prefix and entity identifier.
pub fn Guid::new(prefix : GuidPrefix, entity_id : EntityId) -> Guid {
  { prefix, entity_id, }
}

///|
/// Return the participant prefix of a GUID.
pub fn Guid::prefix(self : Guid) -> GuidPrefix {
  self.prefix
}

///|
/// Return the entity identifier of a GUID.
pub fn Guid::entity_id(self : Guid) -> EntityId {
  self.entity_id
}

///|
/// Serialize a GUID as prefix followed by entity identifier.
pub fn Guid::to_bytes(self : Guid) -> Bytes {
  let bytes : Array[Byte] = []
  let prefix = self.prefix.as_bytes()
  let entity_id = self.entity_id.to_bytes()
  for i in 0..<prefix.length() {
    bytes.push(prefix[i])
  }
  for i in 0..<entity_id.length() {
    bytes.push(entity_id[i])
  }
  Bytes::from_array(bytes)
}

///|
/// Parse a 16-byte GUID.
pub fn Guid::from_bytes(input : Bytes) -> Result[Guid, String] {
  if input.length() != 16 {
    return Err("an RTPS GUID is 16 bytes")
  }
  let prefix = match GuidPrefix::new(bytes_from(input, 0, 12)) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let entity_id = match EntityId::from_bytes(bytes_from(input, 12, 4)) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(Guid::new(prefix, entity_id))
}
