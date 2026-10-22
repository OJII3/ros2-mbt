///|
/// Generate request and response codecs for one service definition.
/// Nested message types are resolved from the workspace and their package
/// imports and RIHS01 hashes are emitted with the generated codecs.
pub fn MessageWorkspace::generate_service_moonbit(
  self : MessageWorkspace,
  package_name : String,
  service_name : String,
  source : String,
) -> Result[String, String] {
  let (request_source, response_source) = match
    rosidl_service_request_response(source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let request_descriptor = match
    MessageSource::new(
      package_name,
      "msg",
      service_name + "_Request",
      request_source,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let response_descriptor = match
    MessageSource::new(
      package_name,
      "msg",
      service_name + "_Response",
      response_source,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let request_types = match self.nested_types_for(request_descriptor) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let response_types = match self.nested_types_for(response_descriptor) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let nested_types : Array[MessageTypeReference] = []
  for reference in request_types {
    nested_types.push(reference)
  }
  for reference in response_types {
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
  let request_imports = match self.imports_for_source(request_descriptor) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let response_imports = match self.imports_for_source(response_descriptor) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let imports : Array[MessageImport] = []
  for mapping in request_imports {
    imports.push(mapping)
  }
  for mapping in response_imports {
    if !rosidl_workspace_contains_import(imports, mapping.ros_package_name) {
      imports.push(mapping)
    }
  }
  let service = match
    parse_service_with_types(package_name, service_name, source, nested_types) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let mut output = rosidl_workspace_import_block(imports) +
    service.generate_moonbit()
  for definition in [service.request(), service.response()] {
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
  match service.type_hash() {
    Ok(_) => ()
    Err(_) => {
      let type_hash = match self.service_type_hash(service) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      output += "\n///|\n"
      output += "pub const " +
        service.service_name() +
        "_TYPE_HASH : String = \"" +
        type_hash +
        "\"\n"
    }
  }
  Ok(output)
}
