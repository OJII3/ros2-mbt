///|
/// Generate an action's goal, result, feedback, SendGoal/GetResult wrapper,
/// and feedback-message codecs. Nested message types are resolved from the
/// workspace and their package imports and RIHS01 hashes are emitted.
/// Action services, status messages, and goal lifecycle are separate layers.
pub fn MessageWorkspace::generate_action_moonbit(
  self : MessageWorkspace,
  package_name : String,
  action_name : String,
  source : String,
) -> Result[String, String] {
  let (goal_source, result_source, feedback_source) = match
    rosidl_action_sections(source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let goal_descriptor = match
    MessageSource::new(package_name, "msg", action_name + "_Goal", goal_source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let result_descriptor = match
    MessageSource::new(
      package_name,
      "msg",
      action_name + "_Result",
      result_source,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let feedback_descriptor = match
    MessageSource::new(
      package_name,
      "msg",
      action_name + "_Feedback",
      feedback_source,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let action_hash_descriptors = [
    MessageSource::new(
      package_name,
      "action",
      action_name + "_Goal",
      goal_source,
    ),
    MessageSource::new(
      package_name,
      "action",
      action_name + "_Result",
      result_source,
    ),
    MessageSource::new(
      package_name,
      "action",
      action_name + "_Feedback",
      feedback_source,
    ),
  ]
  let action_sources : Array[MessageSource] = []
  for descriptor in action_hash_descriptors {
    match descriptor {
      Ok(value) => action_sources.push(value)
      Err(message) => return Err(message)
    }
  }
  let nested_types : Array[MessageTypeReference] = []
  for descriptor in [goal_descriptor, result_descriptor, feedback_descriptor] {
    let references = match self.nested_types_for(descriptor) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    for reference in references {
      let mut already_present = false
      for existing in nested_types {
        if existing.ros_name == reference.ros_name {
          already_present = true
          break
        }
      }
      if !already_present {
        nested_types.push(reference)
      }
    }
  }
  let imports : Array[MessageImport] = []
  for descriptor in [goal_descriptor, result_descriptor, feedback_descriptor] {
    let source_imports = match self.imports_for_source(descriptor) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    for mapping in source_imports {
      if !rosidl_workspace_contains_import(imports, mapping.ros_package_name) {
        imports.push(mapping)
      }
    }
  }
  let action = match
    parse_action_with_types(package_name, action_name, source, nested_types) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let uuid_import = match self.import_for("unique_identifier_msgs") {
    Some(value) => value
    None =>
      return Err(
        "missing MoonBit import for ROS package: unique_identifier_msgs",
      )
  }
  let time_import = match self.import_for("builtin_interfaces") {
    Some(value) => value
    None =>
      return Err("missing MoonBit import for ROS package: builtin_interfaces")
  }
  for mapping in [uuid_import, time_import] {
    if !rosidl_workspace_contains_import(imports, mapping.ros_package_name) {
      imports.push(mapping)
    }
  }
  let protocol_messages = match
    action.protocol_messages(
      "@" + uuid_import.moon_alias + ".UUID",
      "@" + time_import.moon_alias + ".Time",
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let hash_workspace = MessageWorkspace::new()
  for source in self.sources {
    match hash_workspace.add_source(source) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  for mapping in self.imports {
    match hash_workspace.add_import(mapping) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  for source in action_sources {
    if rosidl_workspace_source_index(
        hash_workspace.sources,
        package_name,
        "action",
        source.type_name,
      ) <
      0 {
      match hash_workspace.add_source(source) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    }
  }
  let mut output = rosidl_workspace_import_block(imports) +
    action.generate_moonbit()
  for definition in protocol_messages {
    output += "\n\n" + definition.generate_moonbit()
  }
  for definition in [action.goal(), action.result(), action.feedback()] {
    match definition.type_hash() {
      Ok(_) => ()
      Err(_) => {
        let type_hash = match self.type_hash_for_definition(definition) {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        output += "\n///|\n"
        output += "pub const " +
          definition.type_name() +
          "_TYPE_HASH : String = \"" +
          type_hash +
          "\"\n" +
          definition.generate_type_support(type_hash)
      }
    }
  }
  for definition in protocol_messages {
    match definition.type_hash() {
      Ok(_) => ()
      Err(_) => {
        let type_hash = match
          hash_workspace.type_hash_for_definition(definition) {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        output += "\n///|\n"
        output += "pub const " +
          definition.type_name() +
          "_TYPE_HASH : String = \"" +
          type_hash +
          "\"\n" +
          definition.generate_type_support(type_hash)
      }
    }
  }
  Ok(output)
}
