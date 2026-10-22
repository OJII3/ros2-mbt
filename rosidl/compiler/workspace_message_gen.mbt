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
      Err(_) =>
        match
          self.type_hash(
            definition.package_name(),
            definition.interface_namespace(),
            definition.type_name(),
          ) {
          Ok(type_hash) => {
            output += "\n///|\n"
            output += "pub const " +
              definition.type_name() +
              "_TYPE_HASH : String = \"" +
              type_hash +
              "\"\n" +
              definition.generate_type_support(type_hash)
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
    Err(_) =>
      match self.type_hash(package_name, interface_namespace, type_name) {
        Ok(type_hash) => {
          output += "\n///|\n"
          output += "pub const " +
            definition.type_name() +
            "_TYPE_HASH : String = \"" +
            type_hash +
            "\"\n" +
            definition.generate_type_support(type_hash)
        }
        Err(_) => ()
      }
  }
  Ok(output)
}
