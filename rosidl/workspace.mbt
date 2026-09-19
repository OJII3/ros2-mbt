///|
/// A ROS message source file known to the workspace resolver.
pub struct MessageSource {
  package_name : String
  interface_namespace : String
  type_name : String
  source : String
} derive(Eq, Debug)

///|
/// Create a source descriptor without parsing its contents yet.
pub fn MessageSource::new(
  package_name : String,
  interface_namespace : String,
  type_name : String,
  source : String,
) -> Result[MessageSource, String] {
  if !rosidl_identifier(package_name) ||
    !rosidl_identifier(interface_namespace) ||
    !rosidl_identifier(type_name) {
    return Err("ROS message source names must be identifiers")
  }
  Ok({ package_name, interface_namespace, type_name, source, })
}

///|
pub fn MessageSource::package_name(self : MessageSource) -> String {
  self.package_name
}

///|
pub fn MessageSource::interface_namespace(self : MessageSource) -> String {
  self.interface_namespace
}

///|
pub fn MessageSource::type_name(self : MessageSource) -> String {
  self.type_name
}

///|
pub fn MessageSource::source(self : MessageSource) -> String {
  self.source
}

///|
/// A MoonBit package import used by generated message code.
pub struct MessageImport {
  ros_package_name : String
  moon_package_path : String
  moon_alias : String
} derive(Eq, Debug)

///|
/// Create an import mapping from a ROS package name to a MoonBit package.
pub fn MessageImport::new(
  ros_package_name : String,
  moon_package_path : String,
  moon_alias : String,
) -> Result[MessageImport, String] {
  if !rosidl_identifier(ros_package_name) {
    return Err("ROS import package names must be identifiers")
  }
  if !rosidl_package_path(moon_package_path) {
    return Err("MoonBit import paths must contain identifiers separated by /")
  }
  if !rosidl_identifier(moon_alias) {
    return Err("MoonBit import aliases must be identifiers")
  }
  Ok({ ros_package_name, moon_package_path, moon_alias, })
}

///|
pub fn MessageImport::ros_package_name(self : MessageImport) -> String {
  self.ros_package_name
}

///|
pub fn MessageImport::moon_package_path(self : MessageImport) -> String {
  self.moon_package_path
}

///|
pub fn MessageImport::moon_alias(self : MessageImport) -> String {
  self.moon_alias
}

///|
/// A collection of `.msg` sources and their external package mappings.
pub struct MessageWorkspace {
  sources : Array[MessageSource]
  imports : Array[MessageImport]
}

///|
pub fn MessageWorkspace::new() -> MessageWorkspace {
  { sources: [], imports: [], }
}

///|
/// Add one source, rejecting duplicate ROS message identities.
pub fn MessageWorkspace::add_source(
  self : MessageWorkspace,
  source : MessageSource,
) -> Result[Unit, String] {
  for existing in self.sources {
    if existing.package_name == source.package_name &&
      existing.interface_namespace == source.interface_namespace &&
      existing.type_name == source.type_name {
      return Err("the ROS message source is already registered")
    }
  }
  self.sources.push(source)
  Ok(())
}

///|
/// Add one external package import mapping.
pub fn MessageWorkspace::add_import(
  self : MessageWorkspace,
  mapping : MessageImport,
) -> Result[Unit, String] {
  for existing in self.imports {
    if existing.ros_package_name == mapping.ros_package_name {
      if existing == mapping {
        return Ok(())
      }
      return Err("the ROS package already has a different import mapping")
    }
    if existing.moon_alias == mapping.moon_alias ||
      existing.moon_package_path == mapping.moon_package_path {
      return Err("the MoonBit import alias or path is already in use")
    }
  }
  self.imports.push(mapping)
  Ok(())
}

///|
pub fn MessageWorkspace::source_count(self : MessageWorkspace) -> Int {
  self.sources.length()
}

///|
pub fn MessageWorkspace::import_count(self : MessageWorkspace) -> Int {
  self.imports.length()
}

///|
/// Resolve and parse one source with all nested type references inferred from
/// the workspace and its import mappings.
pub fn MessageWorkspace::resolve(
  self : MessageWorkspace,
  package_name : String,
  interface_namespace : String,
  type_name : String,
) -> Result[MessageDefinition, String] {
  let source_index = rosidl_workspace_source_index(
    self.sources,
    package_name,
    interface_namespace,
    type_name,
  )
  if source_index < 0 {
    return Err("the ROS message source was not found")
  }
  let source = self.sources[source_index]
  let nested_types = match self.nested_types_for(source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  parse_message_with_types(
    source.package_name,
    source.interface_namespace,
    source.type_name,
    source.source,
    nested_types,
  )
}

///|
/// Return local message sources in dependency-first order.
pub fn MessageWorkspace::dependency_order(
  self : MessageWorkspace,
  package_name : String,
  interface_namespace : String,
) -> Result[Array[MessageSource], String] {
  let candidates : Array[Int] = []
  for index in 0..<self.sources.length() {
    let source = self.sources[index]
    if source.package_name == package_name &&
      source.interface_namespace == interface_namespace {
      candidates.push(index)
    }
  }
  if candidates.length() == 0 {
    return Err("the ROS message package was not found")
  }
  let resolved_indices : Array[Int] = []
  while resolved_indices.length() < candidates.length() {
    let mut progress = false
    for candidate in candidates {
      if rosidl_workspace_contains_index(resolved_indices, candidate) {
        continue
      }
      let dependencies = match
        self.local_dependencies(self.sources[candidate]) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let mut ready = true
      for dependency in dependencies {
        if !rosidl_workspace_contains_index(resolved_indices, dependency) {
          ready = false
          break
        }
      }
      if ready {
        resolved_indices.push(candidate)
        progress = true
      }
    }
    if !progress {
      return Err("cyclic ROS message dependency")
    }
  }
  let ordered : Array[MessageSource] = []
  for index in resolved_indices {
    ordered.push(self.sources[index])
  }
  Ok(ordered)
}

///|
/// Generate all message definitions in one ROS package in dependency order.
/// External nested types become qualified `@alias.Type` references and their
/// import declarations are emitted before the generated definitions.
pub fn MessageWorkspace::generate_moonbit(
  self : MessageWorkspace,
  package_name : String,
  interface_namespace : String,
) -> Result[String, String] {
  let ordered = match self.dependency_order(package_name, interface_namespace) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let imports : Array[MessageImport] = []
  let definitions : Array[MessageDefinition] = []
  for source in ordered {
    let nested_types = match self.nested_types_for(source) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let definition = match
      parse_message_with_types(
        source.package_name,
        source.interface_namespace,
        source.type_name,
        source.source,
        nested_types,
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let referenced_types = match
      rosidl_workspace_referenced_types(source.source) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    for referenced_type in referenced_types {
      let (referenced_package, _, qualified) = match
        rosidl_workspace_reference_parts(referenced_type) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      if !qualified || referenced_package == package_name {
        continue
      }
      let mapping = match self.import_for(referenced_package) {
        Some(value) => value
        None => return Err("a ROS message dependency has no MoonBit import")
      }
      if !rosidl_workspace_contains_import(imports, mapping.ros_package_name) {
        imports.push(mapping)
      }
    }
    definitions.push(definition)
  }
  let mut output = rosidl_workspace_import_block(imports)
  for definition in definitions {
    output += definition.generate_moonbit()
    match definition.type_hash() {
      Ok(_) => ()
      Err(_) => match
        self.type_hash(
          definition.package_name(),
          definition.interface_namespace(),
          definition.type_name(),
        ) {
        Ok(type_hash) => {
          output += "\n///|\n"
          output += "pub const " + definition.type_name() +
            "_TYPE_HASH : String = \"" + type_hash + "\"\n"
        }
        Err(_) => ()
      }
    }
    output += "\n"
  }
  Ok(output)
}

///|
/// Generate one message definition and only the imports it needs.
pub fn MessageWorkspace::generate_message_moonbit(
  self : MessageWorkspace,
  package_name : String,
  interface_namespace : String,
  type_name : String,
) -> Result[String, String] {
  let source_index = rosidl_workspace_source_index(
    self.sources,
    package_name,
    interface_namespace,
    type_name,
  )
  if source_index < 0 {
    return Err("the ROS message source was not found")
  }
  let source = self.sources[source_index]
  let definition = match
    self.resolve(package_name, interface_namespace, type_name) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let imports = match self.imports_for_source(source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let mut output = rosidl_workspace_import_block(imports) +
    definition.generate_moonbit()
  match definition.type_hash() {
    Ok(_) => ()
    Err(_) => match self.type_hash(package_name, interface_namespace, type_name) {
      Ok(type_hash) => {
        output += "\n///|\n"
        output += "pub const " + definition.type_name() +
          "_TYPE_HASH : String = \"" + type_hash + "\"\n"
      }
      Err(_) => ()
    }
  }
  Ok(output)
}

///|
fn MessageWorkspace::nested_types_for(
  self : MessageWorkspace,
  source : MessageSource,
) -> Result[Array[MessageTypeReference], String] {
  let referenced_types = match
    rosidl_workspace_referenced_types(source.source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let nested_types : Array[MessageTypeReference] = []
  for referenced_type in referenced_types {
    let reference = match self.reference_for(source, referenced_type) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    nested_types.push(reference)
  }
  Ok(nested_types)
}

///|
fn MessageWorkspace::reference_for(
  self : MessageWorkspace,
  owner : MessageSource,
  type_name : String,
) -> Result[MessageTypeReference, String] {
  let (package_name, referenced_type, qualified) = match
    rosidl_workspace_reference_parts(type_name) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let resolved_package = if qualified {
    package_name
  } else {
    owner.package_name
  }
  let resolved_namespace = if qualified {
    "msg"
  } else {
    owner.interface_namespace
  }
  if resolved_package == owner.package_name {
    let source_index = rosidl_workspace_source_index(
      self.sources,
      resolved_package,
      resolved_namespace,
      referenced_type,
    )
    if source_index < 0 {
      return Err("unresolved ROS message dependency: " + type_name)
    }
    return Ok(MessageTypeReference::new(type_name, referenced_type))
  }
  let mapping = match self.import_for(resolved_package) {
    Some(value) => value
    None =>
      return Err("missing MoonBit import for ROS package: " + resolved_package)
  }
  Ok(
    MessageTypeReference::new(
      type_name,
      "@" + mapping.moon_alias + "." + referenced_type,
    ),
  )
}

///|
fn MessageWorkspace::local_dependencies(
  self : MessageWorkspace,
  source : MessageSource,
) -> Result[Array[Int], String] {
  let referenced_types = match
    rosidl_workspace_referenced_types(source.source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let dependencies : Array[Int] = []
  for referenced_type in referenced_types {
    let (package_name, type_name, qualified) = match
      rosidl_workspace_reference_parts(referenced_type) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let resolved_package = if qualified {
      package_name
    } else {
      source.package_name
    }
    let resolved_namespace = if qualified {
      "msg"
    } else {
      source.interface_namespace
    }
    let dependency = rosidl_workspace_source_index(
      self.sources,
      resolved_package,
      resolved_namespace,
      type_name,
    )
    if resolved_package == source.package_name {
      if dependency < 0 {
        return Err("unresolved ROS message dependency: " + referenced_type)
      }
      if !rosidl_workspace_contains_index(dependencies, dependency) {
        dependencies.push(dependency)
      }
    } else {
      match self.import_for(resolved_package) {
        Some(_) => ()
        None =>
          return Err(
            "missing MoonBit import for ROS package: " + resolved_package,
          )
      }
    }
  }
  Ok(dependencies)
}

///|
fn MessageWorkspace::imports_for_source(
  self : MessageWorkspace,
  source : MessageSource,
) -> Result[Array[MessageImport], String] {
  let referenced_types = match
    rosidl_workspace_referenced_types(source.source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let imports : Array[MessageImport] = []
  for referenced_type in referenced_types {
    let (package_name, _, qualified) = match
      rosidl_workspace_reference_parts(referenced_type) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    if !qualified || package_name == source.package_name {
      continue
    }
    let mapping = match self.import_for(package_name) {
      Some(value) => value
      None =>
        return Err("missing MoonBit import for ROS package: " + package_name)
    }
    if !rosidl_workspace_contains_import(imports, package_name) {
      imports.push(mapping)
    }
  }
  Ok(imports)
}

///|
fn MessageWorkspace::import_for(
  self : MessageWorkspace,
  ros_package_name : String,
) -> MessageImport? {
  for mapping in self.imports {
    if mapping.ros_package_name == ros_package_name {
      return Some(mapping)
    }
  }
  None
}

///|
fn rosidl_workspace_source_index(
  sources : Array[MessageSource],
  package_name : String,
  interface_namespace : String,
  type_name : String,
) -> Int {
  for index in 0..<sources.length() {
    let source = sources[index]
    if source.package_name == package_name &&
      source.interface_namespace == interface_namespace &&
      source.type_name == type_name {
      return index
    }
  }
  -1
}

///|
fn rosidl_workspace_referenced_types(
  source : String,
) -> Result[Array[String], String] {
  let referenced_types : Array[String] = []
  for raw_line in source.split("\n") {
    let line = rosidl_trim(rosidl_without_comment(raw_line.to_owned()))
    if line.length() == 0 {
      continue
    }
    if line.contains("=") && !line.contains("<=") {
      continue
    }
    let words = rosidl_words(line)
    if words.length() != 2 {
      return Err("ROS message fields must have exactly a type and a name")
    }
    let (base_type, _) = match rosidl_parse_field_type(words[0]) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    if rosidl_moon_type(base_type) is Ok(_) {
      continue
    }
    if !rosidl_workspace_contains_string(referenced_types, base_type) {
      referenced_types.push(base_type)
    }
  }
  Ok(referenced_types)
}

///|
fn rosidl_workspace_reference_parts(
  type_name : String,
) -> Result[(String, String, Bool), String] {
  let parts = type_name.split("/").collect()
  if parts.length() == 1 && rosidl_identifier(type_name) {
    return Ok(("", type_name, false))
  }
  if parts.length() == 2 &&
    rosidl_identifier(parts[0].to_owned()) &&
    rosidl_identifier(parts[1].to_owned()) {
    return Ok((parts[0].to_owned(), parts[1].to_owned(), true))
  }
  if parts.length() == 3 &&
    parts[1] == "msg" &&
    rosidl_identifier(parts[0].to_owned()) &&
    rosidl_identifier(parts[2].to_owned()) {
    return Ok((parts[0].to_owned(), parts[2].to_owned(), true))
  }
  Err(
    "ROS message type references must be Type, package/Type, or package/msg/Type",
  )
}

///|
fn rosidl_package_path(value : String) -> Bool {
  let parts = value.split("/").collect()
  if parts.length() == 0 {
    return false
  }
  for part in parts {
    if !rosidl_identifier(part.to_owned()) {
      return false
    }
  }
  true
}

///|
fn rosidl_workspace_contains_string(
  values : Array[String],
  value : String,
) -> Bool {
  for existing in values {
    if existing == value {
      return true
    }
  }
  false
}

///|
fn rosidl_workspace_contains_index(values : Array[Int], value : Int) -> Bool {
  for existing in values {
    if existing == value {
      return true
    }
  }
  false
}

///|
fn rosidl_workspace_contains_import(
  imports : Array[MessageImport],
  ros_package_name : String,
) -> Bool {
  for mapping in imports {
    if mapping.ros_package_name == ros_package_name {
      return true
    }
  }
  false
}

///|
fn rosidl_workspace_import_block(imports : Array[MessageImport]) -> String {
  if imports.length() == 0 {
    return ""
  }
  let mut output = "import {\n"
  for mapping in imports {
    output += "  \"" +
      mapping.moon_package_path +
      "\" @" +
      mapping.moon_alias +
      ",\n"
  }
  output += "}\n\n"
  output
}
