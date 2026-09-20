///|
/// RIHS version prefix used by ROS 2 type-description hashes.
pub const RIHS01_PREFIX : String = "RIHS01_"

///|
fn rosidl_hash_type_name(definition : MessageDefinition) -> String {
  definition.package_name() + "/" + definition.interface_namespace() + "/" +
    definition.type_name()
}

///|
fn rosidl_hash_primitive_type_id(type_name : String) -> Result[Int, String] {
  match type_name {
    "int8" => Ok(2)
    "uint8" => Ok(3)
    "int16" => Ok(4)
    "uint16" => Ok(5)
    "int32" => Ok(6)
    "uint32" => Ok(7)
    "int64" => Ok(8)
    "uint64" => Ok(9)
    "float32" => Ok(10)
    "float64" => Ok(11)
    "char" => Ok(13)
    "bool" => Ok(15)
    "byte" => Ok(16)
    "string" => Ok(17)
    "wstring" => Ok(18)
    _ => Err("the ROS field is a nested type")
  }
}

///|
fn rosidl_hash_json_quote(value : String) -> String {
  let bytes = @utf8.encode(value)
  let mut result = "\""
  for byte in bytes {
    match byte {
      b'"' => result += "\\\""
      b'\\' => result += "\\\\"
      _ => result += @utf8.decode(Bytes::from_array([byte])) catch {
        _ => ""
      }
    }
  }
  result + "\""
}

///|
fn rosidl_hash_field_type_json(
  field : MessageField,
  nested_type_name : String,
) -> Result[String, String] {
  let base_type_id = match field.string_upper_bound() {
    Some(_) => match field.type_name() {
      "string" => 21
      "wstring" => 22
      _ => return Err("a string upper bound requires a string field")
    }
    None =>
      match rosidl_hash_primitive_type_id(field.type_name()) {
        Ok(value) => value
        Err(_) => if nested_type_name.length() > 0 {
          1
        } else {
          return Err("a nested ROS field needs a resolved type description")
        }
      }
  }
  let (type_id, capacity) = match field.collection() {
    MessageFieldCollection::Scalar => (base_type_id, 0)
    MessageFieldCollection::FixedArray(length) => (base_type_id + 48, length)
    MessageFieldCollection::BoundedSequence(length) =>
      (base_type_id + 96, length)
    MessageFieldCollection::Sequence => (base_type_id + 144, 0)
  }
  let type_name = match rosidl_hash_primitive_type_id(field.type_name()) {
    Ok(_) => ""
    Err(_) => nested_type_name
  }
  let string_capacity = match field.string_upper_bound() {
    Some(value) => value
    None => 0
  }
  Ok(
    "{\"type_id\": " + type_id.to_string() +
      ", \"capacity\": " + capacity.to_string() +
      ", \"string_capacity\": " + string_capacity.to_string() +
      ", \"nested_type_name\": " +
      rosidl_hash_json_quote(type_name) + "}",
  )
}

///|
fn rosidl_hash_individual_json(
  definition : MessageDefinition,
  nested_type_names : Array[String],
) -> Result[String, String] {
  let fields = definition.fields()
  let mut result = "{\"type_name\": " +
    rosidl_hash_json_quote(rosidl_hash_type_name(definition)) +
    ", \"fields\": ["
  for index in 0..<fields.length() {
    if index > 0 {
      result += ", "
    }
    let nested_type_name = nested_type_names[index]
    let field = fields[index]
    let field_type = match
      rosidl_hash_field_type_json(field, nested_type_name) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    result += "{\"name\": " + rosidl_hash_json_quote(field.name()) +
      ", \"type\": " + field_type + "}"
  }
  Ok(result + "]}")
}

///|
fn rosidl_hash_string_less(left : String, right : String) -> Bool {
  let left_bytes = @utf8.encode(left)
  let right_bytes = @utf8.encode(right)
  let length = if left_bytes.length() < right_bytes.length() {
    left_bytes.length()
  } else {
    right_bytes.length()
  }
  for index in 0..<length {
    if left_bytes[index] < right_bytes[index] {
      return true
    }
    if left_bytes[index] > right_bytes[index] {
      return false
    }
  }
  left_bytes.length() < right_bytes.length()
}

///|
fn rosidl_hash_sort_definitions(
  definitions : Array[MessageDefinition],
) -> Array[MessageDefinition] {
  let sorted : Array[MessageDefinition] = []
  for definition in definitions {
    sorted.push(definition)
    let mut index = sorted.length() - 1
    while index > 0 &&
      rosidl_hash_string_less(
        rosidl_hash_type_name(sorted[index]),
        rosidl_hash_type_name(sorted[index - 1]),
      ) {
      let previous = sorted[index - 1]
      sorted[index - 1] = sorted[index]
      sorted[index] = previous
      index -= 1
    }
  }
  sorted
}

///|
fn rosidl_hash_json(
  definition : MessageDefinition,
  nested_type_names : Array[String],
  references : Array[(MessageDefinition, Array[String])],
) -> Result[String, String] {
  let top = match rosidl_hash_individual_json(definition, nested_type_names) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let mut result = "{\"type_description\": " + top +
    ", \"referenced_type_descriptions\": ["
  for index in 0..<references.length() {
    if index > 0 {
      result += ", "
    }
    let (reference, field_names) = references[index]
    let individual = match
      rosidl_hash_individual_json(reference, field_names) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    result += individual
  }
  Ok(result + "]}")
}

///|
fn rosidl_sha256_rotr(value : UInt, shift : Int) -> UInt {
  (value >> shift) | (value << (32 - shift))
}

///|
fn rosidl_sha256(input : Bytes) -> Bytes {
  let padding : Array[Byte] = []
  for byte in input {
    padding.push(byte)
  }
  padding.push(0x80)
  while padding.length() % 64 != 56 {
    padding.push(0)
  }
  let bit_length = input.length().to_int64().reinterpret_as_uint64() << 3
  for shift in [56, 48, 40, 32, 24, 16, 8, 0] {
    padding.push((bit_length >> shift).to_byte())
  }

  let constants : Array[UInt] = [
    0x428A2F98U,
    0x71374491U,
    0xB5C0FBCFU,
    0xE9B5DBA5U,
    0x3956C25BU,
    0x59F111F1U,
    0x923F82A4U,
    0xAB1C5ED5U,
    0xD807AA98U,
    0x12835B01U,
    0x243185BEU,
    0x550C7DC3U,
    0x72BE5D74U,
    0x80DEB1FEU,
    0x9BDC06A7U,
    0xC19BF174U,
    0xE49B69C1U,
    0xEFBE4786U,
    0x0FC19DC6U,
    0x240CA1CCU,
    0x2DE92C6FU,
    0x4A7484AAU,
    0x5CB0A9DCU,
    0x76F988DAU,
    0x983E5152U,
    0xA831C66DU,
    0xB00327C8U,
    0xBF597FC7U,
    0xC6E00BF3U,
    0xD5A79147U,
    0x06CA6351U,
    0x14292967U,
    0x27B70A85U,
    0x2E1B2138U,
    0x4D2C6DFCU,
    0x53380D13U,
    0x650A7354U,
    0x766A0ABBU,
    0x81C2C92EU,
    0x92722C85U,
    0xA2BFE8A1U,
    0xA81A664BU,
    0xC24B8B70U,
    0xC76C51A3U,
    0xD192E819U,
    0xD6990624U,
    0xF40E3585U,
    0x106AA070U,
    0x19A4C116U,
    0x1E376C08U,
    0x2748774CU,
    0x34B0BCB5U,
    0x391C0CB3U,
    0x4ED8AA4AU,
    0x5B9CCA4FU,
    0x682E6FF3U,
    0x748F82EEU,
    0x78A5636FU,
    0x84C87814U,
    0x8CC70208U,
    0x90BEFFFAU,
    0xA4506CEBU,
    0xBEF9A3F7U,
    0xC67178F2U,
  ]
  let hash : Array[UInt] = [
    0x6A09E667U,
    0xBB67AE85U,
    0x3C6EF372U,
    0xA54FF53AU,
    0x510E527FU,
    0x9B05688CU,
    0x1F83D9ABU,
    0x5BE0CD19U,
  ]
  let mut block = 0
  while block < padding.length() {
    let words : Array[UInt] = []
    for index in 0..<16 {
      let offset = block + index * 4
      words.push(
        (padding[offset].to_int().reinterpret_as_uint() << 24) |
          (padding[offset + 1].to_int().reinterpret_as_uint() << 16) |
          (padding[offset + 2].to_int().reinterpret_as_uint() << 8) |
          padding[offset + 3].to_int().reinterpret_as_uint(),
      )
    }
    for index in 16..<64 {
      let value15 = words[index - 15]
      let value2 = words[index - 2]
      let sigma0 = rosidl_sha256_rotr(value15, 7) ^
        rosidl_sha256_rotr(value15, 18) ^ (value15 >> 3)
      let sigma1 = rosidl_sha256_rotr(value2, 17) ^
        rosidl_sha256_rotr(value2, 19) ^ (value2 >> 10)
      words.push(words[index - 16] + sigma0 + words[index - 7] + sigma1)
    }
    let mut a = hash[0]
    let mut b = hash[1]
    let mut c = hash[2]
    let mut d = hash[3]
    let mut e = hash[4]
    let mut f = hash[5]
    let mut g = hash[6]
    let mut h = hash[7]
    for index in 0..<64 {
      let sigma1 = rosidl_sha256_rotr(e, 6) ^
        rosidl_sha256_rotr(e, 11) ^ rosidl_sha256_rotr(e, 25)
      let choose = (e & f) ^ ((e ^ 0xFFFFFFFFU) & g)
      let temporary1 = h + sigma1 + choose + constants[index] + words[index]
      let sigma0 = rosidl_sha256_rotr(a, 2) ^
        rosidl_sha256_rotr(a, 13) ^ rosidl_sha256_rotr(a, 22)
      let majority = (a & b) ^ (a & c) ^ (b & c)
      let temporary2 = sigma0 + majority
      h = g
      g = f
      f = e
      e = d + temporary1
      d = c
      c = b
      b = a
      a = temporary1 + temporary2
    }
    hash[0] += a
    hash[1] += b
    hash[2] += c
    hash[3] += d
    hash[4] += e
    hash[5] += f
    hash[6] += g
    hash[7] += h
    block += 64
  }
  let output : Array[Byte] = []
  for value in hash {
    output.push((value >> 24).to_byte())
    output.push((value >> 16).to_byte())
    output.push((value >> 8).to_byte())
    output.push(value.to_byte())
  }
  Bytes::from_array(output)
}

///|
fn rosidl_hash_hex(value : Bytes) -> String {
  let digits = b"0123456789abcdef"
  let output : Array[Byte] = []
  for byte in value {
    output.push(digits[byte.to_int() >> 4])
    output.push(digits[byte.to_int() & 0x0F])
  }
  @utf8.decode(Bytes::from_array(output)) catch {
    _ => ""
  }
}

///|
fn rosidl_hash_string(value : String) -> String {
  RIHS01_PREFIX + rosidl_hash_hex(rosidl_sha256(@utf8.encode(value)))
}

///|
fn rosidl_hash_field_names(
  definition : MessageDefinition,
) -> Result[Array[String], String] {
  let nested_type_names : Array[String] = []
  for field in definition.fields() {
    match rosidl_hash_primitive_type_id(field.type_name()) {
      Ok(_) => nested_type_names.push("")
      Err(_) => {
        let parts = field.type_name().split("/").collect()
        if parts.length() != 3 {
          return Err(
            "a nested ROS field needs a fully qualified type name for hashing",
          )
        }
        nested_type_names.push(field.type_name())
      }
    }
  }
  Ok(nested_type_names)
}

///|
fn rosidl_hash_with_references(
  definition : MessageDefinition,
  references : Array[MessageDefinition],
) -> Result[String, String] {
  let sorted_references = rosidl_hash_sort_definitions(references)
  let reference_json : Array[(MessageDefinition, Array[String])] = []
  for reference in sorted_references {
    let field_names = match rosidl_hash_field_names(reference) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    reference_json.push((reference, field_names))
  }
  let root_field_names = match rosidl_hash_field_names(definition) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let json = match rosidl_hash_json(definition, root_field_names, reference_json) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(rosidl_hash_string(json))
}

///|
/// Calculate a RIHS01 hash for a message containing only primitive fields.
pub fn MessageDefinition::type_hash(
  self : MessageDefinition,
) -> Result[String, String] {
  let nested_type_names = match rosidl_hash_field_names(self) {
    Ok(value) => value
    Err(_) =>
      return Err(
        "MessageDefinition::type_hash needs a MessageWorkspace for nested fields",
      )
  }
  let individual = match
    rosidl_hash_individual_json(self, nested_type_names) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let json = "{\"type_description\": " + individual +
    ", \"referenced_type_descriptions\": []}"
  Ok(rosidl_hash_string(json))
}

///|
/// Build the synthetic ROS service, event, and service metadata definitions.
fn rosidl_service_hash_definitions(
  service : ServiceDefinition,
) -> Result[(MessageDefinition, Array[MessageDefinition]), String] {
  let self = service
  let package_name = self.package_name()
  let service_name = self.service_name()
  let request = self.request
  let response = self.response
  let request_type_name = package_name + "/srv/" + request.type_name()
  let response_type_name = package_name + "/srv/" + response.type_name()
  let event_type_name = package_name + "/srv/" + service_name + "_Event"
  let info_type_name = "service_msgs/msg/ServiceEventInfo"
  let time_type_name = "builtin_interfaces/msg/Time"

  let time = match
    MessageDefinition::new(
      "builtin_interfaces",
      "msg",
      "Time",
      [
        MessageField::new("int32", "sec"),
        MessageField::new("uint32", "nanosec"),
      ],
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let info = match
    MessageDefinition::new_with_types(
      "service_msgs",
      "msg",
      "ServiceEventInfo",
      [
        MessageField::new("uint8", "event_type"),
        MessageField::new(time_type_name, "stamp"),
        MessageField::new("char", "client_gid").with_collection(
          MessageFieldCollection::FixedArray(16),
        ),
        MessageField::new("int64", "sequence_number"),
      ],
      [MessageTypeReference::new(time_type_name, "Time")],
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let event = match
    MessageDefinition::new_with_types(
      package_name,
      "srv",
      service_name + "_Event",
      [
        MessageField::new(info_type_name, "info"),
        MessageField::new(request_type_name, "request").with_collection(
          MessageFieldCollection::BoundedSequence(1),
        ),
        MessageField::new(response_type_name, "response").with_collection(
          MessageFieldCollection::BoundedSequence(1),
        ),
      ],
      [
        MessageTypeReference::new(info_type_name, "ServiceEventInfo"),
        MessageTypeReference::new(request_type_name, request.type_name()),
        MessageTypeReference::new(response_type_name, response.type_name()),
      ],
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let service = match
    MessageDefinition::new_with_types(
      package_name,
      "srv",
      service_name,
      [
        MessageField::new(request_type_name, "request_message"),
        MessageField::new(response_type_name, "response_message"),
        MessageField::new(event_type_name, "event_message"),
      ],
      [
        MessageTypeReference::new(request_type_name, request.type_name()),
        MessageTypeReference::new(response_type_name, response.type_name()),
        MessageTypeReference::new(event_type_name, event.type_name()),
      ],
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok((service, [request, response, event, info, time]))
}

///|
/// Calculate the RIHS01 hash for a primitive-field ROS service type.
///
/// ROS describes a service as a synthetic type containing its request,
/// response, and event message types. The event message also contains the
/// standard service event metadata and one request/response item each.
pub fn ServiceDefinition::type_hash(
  self : ServiceDefinition,
) -> Result[String, String] {
  for field in self.request.fields() {
    match rosidl_hash_primitive_type_id(field.type_name()) {
      Ok(_) => ()
      Err(_) =>
        return Err(
          "ServiceDefinition::type_hash needs a MessageWorkspace for nested request fields",
        )
    }
  }
  for field in self.response.fields() {
    match rosidl_hash_primitive_type_id(field.type_name()) {
      Ok(_) => ()
      Err(_) =>
        return Err(
          "ServiceDefinition::type_hash needs a MessageWorkspace for nested response fields",
        )
    }
  }
  let (service, references) = match rosidl_service_hash_definitions(self) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  rosidl_hash_with_references(service, references)
}

///|
fn rosidl_workspace_type_name_for_field(
  workspace : MessageWorkspace,
  owner : MessageDefinition,
  field : MessageField,
) -> Result[String, String] {
  match rosidl_hash_primitive_type_id(field.type_name()) {
    Ok(_) => Ok("")
    Err(_) => {
      let (package_name, type_name, qualified) = match
        rosidl_workspace_reference_parts(field.type_name()) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let resolved_package = if qualified {
        package_name
      } else {
        owner.package_name()
      }
      let resolved_namespace = if qualified {
        "msg"
      } else if owner.interface_namespace() == "srv" ||
        owner.interface_namespace() == "action" {
        "msg"
      } else {
        owner.interface_namespace()
      }
      if rosidl_workspace_source_index(
        workspace.sources,
        resolved_package,
        resolved_namespace,
        type_name,
      ) < 0 {
        return Err(
          "cannot calculate a type hash without the nested ROS message source: " +
            field.type_name(),
        )
      }
      Ok(resolved_package + "/" + resolved_namespace + "/" + type_name)
    }
  }
}

///|
fn rosidl_service_workspace_type_name_for_field(
  workspace : MessageWorkspace,
  definitions : Array[MessageDefinition],
  owner : MessageDefinition,
  field : MessageField,
) -> Result[String, String] {
  match rosidl_hash_primitive_type_id(field.type_name()) {
    Ok(_) => Ok("")
    Err(_) => {
      for definition in definitions {
        if rosidl_hash_type_name(definition) == field.type_name() {
          return Ok(field.type_name())
        }
      }
      let parts = field.type_name().split("/").collect()
      if parts.length() == 1 && owner.interface_namespace() == "srv" {
        let local_message_name = owner.package_name() + "/msg/" +
          field.type_name()
        if rosidl_workspace_source_index(
          workspace.sources,
          owner.package_name(),
          "msg",
          field.type_name(),
        ) >= 0 {
          return Ok(local_message_name)
        }
      }
      rosidl_workspace_type_name_for_field(workspace, owner, field)
    }
  }
}

///|
fn rosidl_hash_with_service_workspace(
  workspace : MessageWorkspace,
  service : ServiceDefinition,
) -> Result[String, String] {
  let (root, references) = match rosidl_service_hash_definitions(service) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let definitions : Array[MessageDefinition] = [root]
  for reference in references {
    definitions.push(reference)
  }
  let mut index = 0
  while index < definitions.length() {
    let definition = definitions[index]
    for field in definition.fields() {
      let nested_name = match
        rosidl_service_workspace_type_name_for_field(
          workspace, definitions, definition, field,
        ) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      if nested_name.length() > 0 &&
        !rosidl_workspace_find_definition(definitions, nested_name) {
        let nested = match
          rosidl_workspace_resolve_type_name(workspace, nested_name) {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        definitions.push(nested)
      }
    }
    index += 1
  }
  let reference_definitions : Array[MessageDefinition] = []
  for reference_index in 1..<definitions.length() {
    reference_definitions.push(definitions[reference_index])
  }
  let sorted_references = rosidl_hash_sort_definitions(reference_definitions)
  let reference_json : Array[(MessageDefinition, Array[String])] = []
  for reference in sorted_references {
    let field_names : Array[String] = []
    for field in reference.fields() {
      let nested_name = match
        rosidl_service_workspace_type_name_for_field(
          workspace, definitions, reference, field,
        ) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      field_names.push(nested_name)
    }
    reference_json.push((reference, field_names))
  }
  let root_field_names : Array[String] = []
  for field in root.fields() {
    let nested_name = match
      rosidl_service_workspace_type_name_for_field(
        workspace, definitions, root, field,
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    root_field_names.push(nested_name)
  }
  let json = match rosidl_hash_json(root, root_field_names, reference_json) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(rosidl_hash_string(json))
}

///|
/// Calculate a RIHS01 service hash using nested message sources in a workspace.
pub fn MessageWorkspace::service_type_hash(
  self : MessageWorkspace,
  service : ServiceDefinition,
) -> Result[String, String] {
  rosidl_hash_with_service_workspace(self, service)
}

///|
/// Calculate a RIHS01 hash for one message definition using nested sources in
/// the workspace. This also accepts generated service request/response types.
pub fn MessageWorkspace::type_hash_for_definition(
  self : MessageWorkspace,
  root : MessageDefinition,
) -> Result[String, String] {
  rosidl_hash_with_workspace(self, root)
}

///|
fn rosidl_workspace_find_definition(
  definitions : Array[MessageDefinition],
  type_name : String,
) -> Bool {
  for definition in definitions {
    if rosidl_hash_type_name(definition) == type_name {
      return true
    }
  }
  false
}

///|
fn rosidl_workspace_resolve_type_name(
  workspace : MessageWorkspace,
  type_name : String,
) -> Result[MessageDefinition, String] {
  let parts = type_name.split("/").collect()
  if parts.length() != 3 {
    return Err("an internal ROS type hash reference is not fully qualified")
  }
  workspace.resolve(parts[0].to_owned(), parts[1].to_owned(), parts[2].to_owned())
}

///|
/// Calculate a RIHS01 hash with all nested message definitions from a workspace.
pub fn MessageWorkspace::type_hash(
  self : MessageWorkspace,
  package_name : String,
  interface_namespace : String,
  type_name : String,
) -> Result[String, String] {
  let root = match self.resolve(package_name, interface_namespace, type_name) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  self.type_hash_for_definition(root)
}

///|
fn rosidl_hash_with_workspace(
  workspace : MessageWorkspace,
  root : MessageDefinition,
) -> Result[String, String] {
  let definitions : Array[MessageDefinition] = [root]
  let mut index = 0
  while index < definitions.length() {
    let definition = definitions[index]
    for field in definition.fields() {
      let nested_name = match
        rosidl_workspace_type_name_for_field(workspace, definition, field) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      if nested_name.length() > 0 &&
        !rosidl_workspace_find_definition(definitions, nested_name) {
        let nested = match
          rosidl_workspace_resolve_type_name(workspace, nested_name) {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        definitions.push(nested)
      }
    }
    index += 1
  }
  let reference_definitions : Array[MessageDefinition] = []
  for reference_index in 1..<definitions.length() {
    reference_definitions.push(definitions[reference_index])
  }
  let references = rosidl_hash_sort_definitions(reference_definitions)
  let reference_json : Array[(MessageDefinition, Array[String])] = []
  for reference in references {
    let field_names : Array[String] = []
    for field in reference.fields() {
      let nested_name = match
        rosidl_workspace_type_name_for_field(workspace, reference, field) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      field_names.push(nested_name)
    }
    reference_json.push((reference, field_names))
  }
  let root_field_names : Array[String] = []
  for field in root.fields() {
    let nested_name = match
      rosidl_workspace_type_name_for_field(workspace, root, field) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    root_field_names.push(nested_name)
  }
  let json = match rosidl_hash_json(root, root_field_names, reference_json) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(rosidl_hash_string(json))
}
