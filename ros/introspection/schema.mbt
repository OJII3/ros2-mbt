///|
priv struct PendingMessageType {
  package_name : String
  type_name : String
}

///|
/// A message definition and all nested definitions needed to decode it.
pub struct MessageSchema {
  root : @rosidl.MessageDefinition
  definitions : Array[@rosidl.MessageDefinition]
}

///|
/// Return the root message definition.
pub fn MessageSchema::root(self : MessageSchema) -> @rosidl.MessageDefinition {
  self.root
}

///|
/// Find a loaded message definition by package and type name.
pub fn MessageSchema::find(
  self : MessageSchema,
  package_name : String,
  type_name : String,
) -> @rosidl.MessageDefinition? {
  for definition in self.definitions {
    if definition.package_name() == package_name &&
      definition.type_name() == type_name {
      return Some(definition)
    }
  }
  None
}

///|
fn parse_ros_type_path(type_path : String) -> Result[(String, String), String] {
  let parts = type_path.split("/").collect()
  if parts.length() != 3 || parts[1] != "msg" {
    return Err("expected a ROS message type such as package/msg/Type")
  }
  Ok((parts[0].to_owned(), parts[2].to_owned()))
}

///|
fn parse_nested_type_path(
  owner_package : String,
  type_name : String,
) -> Result[(String, String), String] {
  let parts = type_name.split("/").collect()
  if parts.length() == 1 {
    return Ok((owner_package, type_name))
  }
  if parts.length() == 2 {
    return Ok((parts[0].to_owned(), parts[1].to_owned()))
  }
  if parts.length() == 3 && parts[1] == "msg" {
    return Ok((parts[0].to_owned(), parts[2].to_owned()))
  }
  Err("invalid nested ROS message type: " + type_name)
}

///|
async fn find_message_source(
  package_name : String,
  type_name : String,
) -> Result[(String, String), String] {
  let prefixes = match @env.get_env_var("AMENT_PREFIX_PATH") {
    Some(value) => value.split(":").collect()
    None =>
      return Err(
        "AMENT_PREFIX_PATH is not set; source a ROS interface environment",
      )
  }
  for prefix in prefixes {
    let path = prefix.to_owned() +
      "/share/" +
      package_name +
      "/msg/" +
      type_name +
      ".msg"
    if @fs.exists(path) {
      let source = @fs.read_file(path).text() catch {
        _ => return Err("could not read ROS message definition: " + path)
      }
      return Ok((path, source))
    }
  }
  Err(
    "ROS message definition not found for " +
    package_name +
    "/msg/" +
    type_name +
    " in AMENT_PREFIX_PATH",
  )
}

///|
async fn load_message_source(
  package_name : String,
  type_name : String,
) -> Result[@rosidl.MessageSource, String] {
  let (_, source_text) = match find_message_source(package_name, type_name) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  @rosidl.MessageSource::new(package_name, "msg", type_name, source_text)
}

///|
/// Load a ROS message type and its nested `.msg` definitions from AMENT prefixes.
pub async fn load_message_schema(
  type_path : String,
) -> Result[MessageSchema, String] {
  let (root_package, root_type) = match parse_ros_type_path(type_path) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let pending = [{ package_name: root_package, type_name: root_type, }]
  let sources : Array[@rosidl.MessageSource] = []
  let mut cursor = 0
  while cursor < pending.length() {
    let current = pending[cursor]
    cursor += 1
    let mut already_loaded = false
    for source in sources {
      if source.package_name() == current.package_name &&
        source.type_name() == current.type_name {
        already_loaded = true
        break
      }
    }
    if already_loaded {
      continue
    }
    let source = match
      load_message_source(current.package_name, current.type_name) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let references = match @rosidl.message_referenced_types(source.source()) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    for reference in references {
      let (package_name, type_name) = match
        parse_nested_type_path(current.package_name, reference) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      pending.push({ package_name, type_name, })
    }
    sources.push(source)
  }
  let definitions : Array[@rosidl.MessageDefinition] = []
  for source in sources {
    let references = match @rosidl.message_referenced_types(source.source()) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let nested_types : Array[@rosidl.MessageTypeReference] = []
    for reference in references {
      nested_types.push(
        @rosidl.MessageTypeReference::new(reference, "NestedMessage"),
      )
    }
    let definition = match
      @rosidl.parse_message_with_types(
        source.package_name(),
        "msg",
        source.type_name(),
        source.source(),
        nested_types,
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    definitions.push(definition)
  }
  if definitions.length() == 0 {
    return Err("the ROS message schema is empty")
  }
  let root = definitions[0]
  Ok({ root, definitions, })
}
