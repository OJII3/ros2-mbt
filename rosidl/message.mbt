///|
/// The collection shape of a ROS message field.
pub(all) enum MessageFieldCollection {
  Scalar
  FixedArray(Int)
  Sequence
  BoundedSequence(Int)
} derive(Eq, Debug)

///|
/// A field in a ROS `.msg` definition.
pub struct MessageField {
  type_name : String
  name : String
  collection : MessageFieldCollection
} derive(Eq, Debug)

///|
/// A nested message type available to the code generator.
pub struct MessageTypeReference {
  ros_name : String
  moon_name : String
} derive(Eq, Debug)

///|
/// A scalar constant declared in a ROS `.msg` definition.
pub struct MessageConstant {
  type_name : String
  name : String
  value : String
} derive(Eq, Debug)

///|
/// A parsed ROS message definition containing supported primitive fields.
pub struct MessageDefinition {
  package_name : String
  interface_namespace : String
  type_name : String
  fields : Array[MessageField]
  constants : Array[MessageConstant]
  nested_types : Array[MessageTypeReference]
} derive(Eq, Debug)

///|
/// A parsed ROS service definition containing request and response messages.
pub struct ServiceDefinition {
  package_name : String
  service_name : String
  request : MessageDefinition
  response : MessageDefinition
} derive(Eq, Debug)

///|
/// Create a message field descriptor.
pub fn MessageField::new(type_name : String, name : String) -> MessageField {
  { type_name, name, collection: MessageFieldCollection::Scalar, }
}

///|
/// Return a copy of the field with an explicit collection shape.
pub fn MessageField::with_collection(
  self : MessageField,
  collection : MessageFieldCollection,
) -> MessageField {
  { ..self, collection, }
}

///|
/// Return the ROS type spelling of this field.
pub fn MessageField::type_name(self : MessageField) -> String {
  self.type_name
}

///|
/// Return the field identifier.
pub fn MessageField::name(self : MessageField) -> String {
  self.name
}

///|
/// Return whether the field is scalar, fixed-size, or a sequence.
pub fn MessageField::collection(self : MessageField) -> MessageFieldCollection {
  self.collection
}

///|
/// Create a nested message type reference for the code generator.
pub fn MessageTypeReference::new(
  ros_name : String,
  moon_name : String,
) -> MessageTypeReference {
  { ros_name, moon_name, }
}

///|
/// Return the ROS spelling of a nested message type.
pub fn MessageTypeReference::ros_name(self : MessageTypeReference) -> String {
  self.ros_name
}

///|
/// Return the MoonBit type name used in generated code.
pub fn MessageTypeReference::moon_name(self : MessageTypeReference) -> String {
  self.moon_name
}

///|
/// Create a message constant descriptor.
pub fn MessageConstant::new(
  type_name : String,
  name : String,
  value : String,
) -> MessageConstant {
  { type_name, name, value, }
}

///|
/// Return the ROS type spelling of this constant.
pub fn MessageConstant::type_name(self : MessageConstant) -> String {
  self.type_name
}

///|
/// Return the constant identifier.
pub fn MessageConstant::name(self : MessageConstant) -> String {
  self.name
}

///|
/// Return the source literal spelling of this constant.
pub fn MessageConstant::value(self : MessageConstant) -> String {
  self.value
}

///|
/// Create a validated message definition from its fields.
pub fn MessageDefinition::new(
  package_name : String,
  interface_namespace : String,
  type_name : String,
  fields : Array[MessageField],
) -> Result[MessageDefinition, String] {
  let nested_types : Array[MessageTypeReference] = []
  MessageDefinition::new_with_types(
    package_name, interface_namespace, type_name, fields, nested_types,
  )
}

///|
/// Create a validated message definition with nested message type references.
pub fn MessageDefinition::new_with_types(
  package_name : String,
  interface_namespace : String,
  type_name : String,
  fields : Array[MessageField],
  nested_types : Array[MessageTypeReference],
) -> Result[MessageDefinition, String] {
  if !rosidl_identifier(package_name) ||
    !rosidl_identifier(interface_namespace) ||
    !rosidl_identifier(type_name) {
    return Err("ROS message package, namespace, and type must be identifiers")
  }
  for nested_type in nested_types {
    if !rosidl_type_reference_name(nested_type.ros_name) {
      return Err("ROS nested message type names must be identifiers or paths")
    }
    if !rosidl_moon_type_reference_name(nested_type.moon_name) {
      return Err(
        "MoonBit nested message type names must be identifiers or qualified references",
      )
    }
  }
  for field in fields {
    if !rosidl_identifier(field.name) {
      return Err("ROS message field names must be identifiers")
    }
    match rosidl_moon_type_for_field(field.type_name, nested_types) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    match field.collection {
      MessageFieldCollection::FixedArray(length) =>
        if length <= 0 {
          return Err("ROS fixed array lengths must be positive")
        }
      MessageFieldCollection::Scalar => ()
      MessageFieldCollection::Sequence => ()
      MessageFieldCollection::BoundedSequence(length) =>
        if length <= 0 {
          return Err("ROS bounded sequence lengths must be positive")
        }
    }
  }
  Ok({
    package_name,
    interface_namespace,
    type_name,
    fields,
    constants: [],
    nested_types,
  })
}

///|
/// Add validated constants to a parsed message definition.
pub fn MessageDefinition::with_constants(
  self : MessageDefinition,
  constants : Array[MessageConstant],
) -> Result[MessageDefinition, String] {
  for constant in constants {
    if !rosidl_identifier(constant.name) {
      return Err("ROS message constant names must be identifiers")
    }
    match rosidl_constant_literal(constant.type_name, constant.value) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok({ ..self, constants, })
}

///|
/// Return the nested type references used by this definition.
pub fn MessageDefinition::nested_types(
  self : MessageDefinition,
) -> Array[MessageTypeReference] {
  self.nested_types
}

///|
/// Return the ROS package name.
pub fn MessageDefinition::package_name(self : MessageDefinition) -> String {
  self.package_name
}

///|
/// Return the ROS interface namespace, usually `msg`.
pub fn MessageDefinition::interface_namespace(
  self : MessageDefinition,
) -> String {
  self.interface_namespace
}

///|
/// Return the ROS message type name.
pub fn MessageDefinition::type_name(self : MessageDefinition) -> String {
  self.type_name
}

///|
/// Return the parsed scalar fields.
pub fn MessageDefinition::fields(
  self : MessageDefinition,
) -> Array[MessageField] {
  self.fields
}

///|
/// Return the declared constants.
pub fn MessageDefinition::constants(
  self : MessageDefinition,
) -> Array[MessageConstant] {
  self.constants
}

///|
/// Create a service definition from its request and response messages.
pub fn ServiceDefinition::new(
  package_name : String,
  service_name : String,
  request : MessageDefinition,
  response : MessageDefinition,
) -> Result[ServiceDefinition, String] {
  if !rosidl_identifier(package_name) || !rosidl_identifier(service_name) {
    return Err("ROS service package and type must be identifiers")
  }
  if request.package_name() != package_name ||
    request.interface_namespace() != "srv" ||
    request.type_name() != service_name + "_Request" {
    return Err("ROS service request definition has the wrong identity")
  }
  if response.package_name() != package_name ||
    response.interface_namespace() != "srv" ||
    response.type_name() != service_name + "_Response" {
    return Err("ROS service response definition has the wrong identity")
  }
  Ok({ package_name, service_name, request, response, })
}

///|
pub fn ServiceDefinition::package_name(self : ServiceDefinition) -> String {
  self.package_name
}

///|
pub fn ServiceDefinition::service_name(self : ServiceDefinition) -> String {
  self.service_name
}

///|
pub fn ServiceDefinition::request(
  self : ServiceDefinition,
) -> MessageDefinition {
  self.request
}

///|
pub fn ServiceDefinition::response(
  self : ServiceDefinition,
) -> MessageDefinition {
  self.response
}

///|
/// Generate request and response MoonBit CDR codecs for a ROS service.
pub fn ServiceDefinition::generate_moonbit(self : ServiceDefinition) -> String {
  let output = self.request.generate_moonbit() + "\n" +
    self.response.generate_moonbit()
  match self.type_hash() {
    Ok(type_hash) => output +
      "\n///|\n" +
      "pub const " + self.service_name + "_TYPE_HASH : String = \"" +
      type_hash + "\"\n"
    Err(_) => output
  }
}

///|
/// Parse the primitive-field subset of a ROS `.msg` definition.
///
/// Blank lines and `#` comments are ignored. Fixed arrays (`type[N]`) and
/// unbounded sequences (`type[]`), bounded sequences (`type[<=N]`), and scalar
/// constants are supported. Nested message fields can be enabled with
/// `parse_message_with_types`.
pub fn parse_message(
  package_name : String,
  interface_namespace : String,
  type_name : String,
  source : String,
) -> Result[MessageDefinition, String] {
  let nested_types : Array[MessageTypeReference] = []
  parse_message_with_types(
    package_name, interface_namespace, type_name, source, nested_types,
  )
}

///|
/// Parse a ROS `.msg` definition with explicitly supplied nested message types.
pub fn parse_message_with_types(
  package_name : String,
  interface_namespace : String,
  type_name : String,
  source : String,
  nested_types : Array[MessageTypeReference],
) -> Result[MessageDefinition, String] {
  let fields : Array[MessageField] = []
  let constants : Array[MessageConstant] = []
  for raw_line in source.split("\n") {
    let line = rosidl_trim(rosidl_without_comment(raw_line.to_owned()))
    if line.length() == 0 {
      continue
    }
    let equal_parts = line.split("=").collect()
    if line.contains("=") && !line.contains("<=") {
      if equal_parts.length() != 2 {
        return Err("ROS message constants must contain one =")
      }
      let declaration = rosidl_words(equal_parts[0].to_owned())
      if declaration.length() != 2 {
        return Err("ROS message constants must have a type and a name")
      }
      let value = rosidl_trim(equal_parts[1].to_owned())
      match rosidl_constant_literal(declaration[0], value) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
      constants.push(
        MessageConstant::new(declaration[0], declaration[1], value),
      )
      continue
    }
    let words = rosidl_words(line)
    if words.length() != 2 {
      return Err("ROS message fields must have exactly a type and a name")
    }
    let (base_type, collection) = match rosidl_parse_field_type(words[0]) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    if !rosidl_identifier(words[1]) {
      return Err("ROS message field names must be identifiers")
    }
    fields.push(
      MessageField::new(base_type, words[1]).with_collection(collection),
    )
  }
  let definition = match
    MessageDefinition::new_with_types(
      package_name, interface_namespace, type_name, fields, nested_types,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  definition.with_constants(constants)
}

///|
/// Parse a ROS service definition into request and response message codecs.
pub fn parse_service(
  package_name : String,
  service_name : String,
  source : String,
) -> Result[ServiceDefinition, String] {
  parse_service_with_types(package_name, service_name, source, [])
}

///|
/// Parse a ROS service definition with explicit nested message references.
pub fn parse_service_with_types(
  package_name : String,
  service_name : String,
  source : String,
  nested_types : Array[MessageTypeReference],
) -> Result[ServiceDefinition, String] {
  let sections = source.split("---").collect()
  if sections.length() != 2 {
    return Err("ROS service definitions must contain one --- separator")
  }
  let request = match
    parse_message_with_types(
      package_name,
      "srv",
      service_name + "_Request",
      sections[0].to_owned(),
      nested_types,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let response = match
    parse_message_with_types(
      package_name,
      "srv",
      service_name + "_Response",
      sections[1].to_owned(),
      nested_types,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  ServiceDefinition::new(package_name, service_name, request, response)
}

///|
fn rosidl_words(line : String) -> Array[String] {
  let words : Array[String] = []
  for raw_word in line.split(" ") {
    let word = rosidl_trim(raw_word.to_owned())
    if word.length() > 0 {
      words.push(word)
    }
  }
  words
}

///|
fn rosidl_parse_field_type(
  type_spec : String,
) -> Result[(String, MessageFieldCollection), String] {
  let parts = type_spec.split("[").collect()
  if parts.length() == 1 {
    Ok((parts[0].to_owned(), MessageFieldCollection::Scalar))
  } else if parts.length() != 2 {
    Err("ROS message field type has an invalid collection suffix")
  } else {
    let base_type = parts[0].to_owned()
    let suffix = parts[1].to_owned()
    if suffix.length() == 0 || suffix[suffix.length() - 1] != ']' {
      return Err("ROS message collection type must end with ]")
    }
    let inner = suffix[0:suffix.length() - 1].to_owned()
    if inner.length() == 0 {
      Ok((base_type, MessageFieldCollection::Sequence))
    } else if inner[0] == '<' {
      if inner.length() <= 2 || inner[1] != '=' {
        return Err("ROS bounded sequence must use the <=N form")
      }
      let bound = match rosidl_positive_int(inner[2:].to_owned()) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      Ok((base_type, MessageFieldCollection::BoundedSequence(bound)))
    } else {
      let length = match rosidl_positive_int(inner) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      Ok((base_type, MessageFieldCollection::FixedArray(length)))
    }
  }
}

///|
fn rosidl_positive_int(value : String) -> Result[Int, String] {
  let bytes = @utf8.encode(value)
  if bytes.length() == 0 {
    return Err("ROS fixed array length must not be empty")
  }
  let mut result = 0
  for byte in bytes {
    if byte < 48 || byte > 57 {
      return Err("ROS fixed array length must be a positive integer")
    }
    if result > 1000000 {
      return Err("ROS fixed array length is too large")
    }
    result = result * 10 + (byte.to_int() - 48)
  }
  if result <= 0 {
    return Err("ROS fixed array length must be positive")
  }
  Ok(result)
}

///|
/// Generate a MoonBit struct and CDR codec for a parsed message definition.
pub fn MessageDefinition::generate_moonbit(self : MessageDefinition) -> String {
  let mut output = "///|\n" +
    "/// Generated from " +
    self.package_name +
    "/" +
    self.interface_namespace +
    "/" +
    self.type_name +
    ".msg\n" +
    "pub struct " +
    self.type_name +
    " {\n"
  for field in self.fields {
    output += "  " +
      field.name +
      " : " +
      rosidl_field_moon_type(field, self.nested_types) +
      "\n"
  }
  output += "} derive(Eq, Debug)\n\n"
  match self.type_hash() {
    Ok(type_hash) => {
      output += "///|\n"
      output += "pub const " + self.type_name + "_TYPE_HASH : String = \"" +
        type_hash + "\"\n\n"
    }
    Err(_) => ()
  }
  for constant in self.constants {
    output += "///|\n"
    output += "pub const " +
      constant.name +
      " : " +
      rosidl_moon_type(constant.type_name).unwrap() +
      " = " +
      rosidl_constant_literal(constant.type_name, constant.value).unwrap() +
      "\n\n"
  }
  output += "///|\n"
  output += "pub fn " + self.type_name + "::new(\n"
  for field in self.fields {
    output += "  " +
      field.name +
      " : " +
      rosidl_field_moon_type(field, self.nested_types) +
      ",\n"
  }
  output += ") -> " + self.type_name + " {\n  {\n"
  for field in self.fields {
    output += "    " + field.name + ",\n"
  }
  output += "  }\n}\n\n"
  for field in self.fields {
    output += "///|\n"
    output += "pub fn " +
      self.type_name +
      "::" +
      field.name +
      "(self : " +
      self.type_name +
      ") -> " +
      rosidl_field_moon_type(field, self.nested_types) +
      " {\n"
    output += "  self." + field.name + "\n}\n\n"
  }
  output += "///|\n"
  output += "pub fn " +
    self.type_name +
    "::write_cdr(self : " +
    self.type_name +
    ", writer : @cdr.Writer) -> Unit {\n"
  for field in self.fields {
    output += rosidl_generate_writer(field)
  }
  output += "}\n\n"
  output += "///|\n"
  output += "pub fn " +
    self.type_name +
    "::read_cdr(reader : @cdr.Reader) -> Result[" +
    self.type_name +
    ", String] {\n"
  for field in self.fields {
    output += rosidl_generate_reader(field, self.nested_types)
  }
  output += "  Ok(" + self.type_name + "::new(\n"
  for field in self.fields {
    output += "    " + field.name + ",\n"
  }
  output += "  ))\n}\n\n"
  output += "///|\n"
  output += "pub fn " +
    self.type_name +
    "::to_cdr_bytes(self : " +
    self.type_name +
    ") -> Bytes {\n"
  output += "  let writer = @cdr.Writer::new()\n"
  output += "  self.write_cdr(writer)\n"
  output += "  writer.to_bytes()\n}\n\n"
  output += "///|\n"
  output += "pub fn " +
    self.type_name +
    "::from_cdr_bytes(input : Bytes) -> Result[" +
    self.type_name +
    ", String] {\n"
  output += "  let reader = match @cdr.Reader::from_bytes(input) {\n"
  output += "    Ok(value) => value\n"
  output += "    Err(message) => return Err(message)\n"
  output += "  }\n"
  output += "  let value = match " + self.type_name + "::read_cdr(reader) {\n"
  output += "    Ok(value) => value\n"
  output += "    Err(message) => return Err(message)\n"
  output += "  }\n"
  output += "  if reader.remaining() != 0 {\n"
  output += "    return Err(\"trailing bytes after generated ROS message\")\n"
  output += "  }\n"
  output += "  Ok(value)\n}\n"
  output
}

///|
fn rosidl_field_moon_type(
  field : MessageField,
  nested_types : Array[MessageTypeReference],
) -> String {
  let base = rosidl_moon_type_for_field(field.type_name, nested_types).unwrap()
  match field.collection {
    MessageFieldCollection::Scalar => base
    MessageFieldCollection::FixedArray(_) => "Array[" + base + "]"
    MessageFieldCollection::Sequence => "Array[" + base + "]"
    MessageFieldCollection::BoundedSequence(_) => "Array[" + base + "]"
  }
}

///|
fn rosidl_generate_writer(field : MessageField) -> String {
  let codec_method = rosidl_writer_method(field.type_name)
  if rosidl_moon_type(field.type_name) is Err(_) {
    return rosidl_generate_nested_writer(field)
  }
  match field.collection {
    MessageFieldCollection::Scalar =>
      "  writer." + codec_method + "(self." + field.name + ")\n"
    MessageFieldCollection::FixedArray(_) =>
      "  for value in self." +
      field.name +
      " {\n" +
      "    writer." +
      codec_method +
      "(value)\n" +
      "  }\n"
    MessageFieldCollection::Sequence =>
      "  writer.write_u32(self." +
      field.name +
      ".length().reinterpret_as_uint())\n" +
      "  for value in self." +
      field.name +
      " {\n" +
      "    writer." +
      codec_method +
      "(value)\n" +
      "  }\n"
    MessageFieldCollection::BoundedSequence(_) =>
      "  writer.write_u32(self." +
      field.name +
      ".length().reinterpret_as_uint())\n" +
      "  for value in self." +
      field.name +
      " {\n" +
      "    writer." +
      codec_method +
      "(value)\n" +
      "  }\n"
  }
}

///|
fn rosidl_generate_reader(
  field : MessageField,
  nested_types : Array[MessageTypeReference],
) -> String {
  let codec_method = rosidl_reader_method(field.type_name)
  let base = rosidl_moon_type_for_field(field.type_name, nested_types).unwrap()
  if rosidl_moon_type(field.type_name) is Err(_) {
    return rosidl_generate_nested_reader(field, base)
  }
  match field.collection {
    MessageFieldCollection::Scalar =>
      "  let " +
      field.name +
      " = match reader." +
      codec_method +
      "() {\n" +
      "    Ok(value) => value\n" +
      "    Err(message) => return Err(message)\n" +
      "  }\n"
    MessageFieldCollection::FixedArray(length) =>
      "  let " +
      field.name +
      " : Array[" +
      base +
      "] = []\n" +
      "  for _ in 0..<" +
      length.to_string() +
      " {\n" +
      "    " +
      field.name +
      ".push(match reader." +
      codec_method +
      "() {\n" +
      "      Ok(value) => value\n" +
      "      Err(message) => return Err(message)\n" +
      "    })\n" +
      "  }\n"
    MessageFieldCollection::Sequence =>
      "  let " +
      field.name +
      "_length = match reader.read_u32() {\n" +
      "    Ok(value) => value.reinterpret_as_int()\n" +
      "    Err(message) => return Err(message)\n" +
      "  }\n" +
      "  if " +
      field.name +
      "_length < 0 || " +
      field.name +
      "_length > reader.remaining() {\n" +
      "    return Err(\"generated ROS sequence is truncated\")\n" +
      "  }\n" +
      "  let " +
      field.name +
      " : Array[" +
      base +
      "] = []\n" +
      "  for _ in 0..<" +
      field.name +
      "_length {\n" +
      "    " +
      field.name +
      ".push(match reader." +
      codec_method +
      "() {\n" +
      "      Ok(value) => value\n" +
      "      Err(message) => return Err(message)\n" +
      "    })\n" +
      "  }\n"
    MessageFieldCollection::BoundedSequence(bound) =>
      "  let " +
      field.name +
      "_length = match reader.read_u32() {\n" +
      "    Ok(value) => value.reinterpret_as_int()\n" +
      "    Err(message) => return Err(message)\n" +
      "  }\n" +
      "  if " +
      field.name +
      "_length < 0 || " +
      field.name +
      "_length > " +
      bound.to_string() +
      " {\n" +
      "    return Err(\"generated ROS bounded sequence exceeds its bound\")\n" +
      "  }\n" +
      "  if " +
      field.name +
      "_length > reader.remaining() {\n" +
      "    return Err(\"generated ROS sequence is truncated\")\n" +
      "  }\n" +
      "  let " +
      field.name +
      " : Array[" +
      base +
      "] = []\n" +
      "  for _ in 0..<" +
      field.name +
      "_length {\n" +
      "    " +
      field.name +
      ".push(match reader." +
      codec_method +
      "() {\n" +
      "      Ok(value) => value\n" +
      "      Err(message) => return Err(message)\n" +
      "    })\n" +
      "  }\n"
  }
}

///|
fn rosidl_generate_nested_writer(field : MessageField) -> String {
  match field.collection {
    MessageFieldCollection::Scalar =>
      "  self." + field.name + ".write_cdr(writer)\n"
    MessageFieldCollection::FixedArray(_) =>
      "  for value in self." +
      field.name +
      " {\n" +
      "    value.write_cdr(writer)\n" +
      "  }\n"
    MessageFieldCollection::Sequence
    | MessageFieldCollection::BoundedSequence(_) =>
      "  writer.write_u32(self." +
      field.name +
      ".length().reinterpret_as_uint())\n" +
      "  for value in self." +
      field.name +
      " {\n" +
      "    value.write_cdr(writer)\n" +
      "  }\n"
  }
}

///|
fn rosidl_generate_nested_reader(
  field : MessageField,
  nested_type : String,
) -> String {
  match field.collection {
    MessageFieldCollection::Scalar =>
      "  let " +
      field.name +
      " = match " +
      nested_type +
      "::read_cdr(reader) {\n" +
      "    Ok(value) => value\n" +
      "    Err(message) => return Err(message)\n" +
      "  }\n"
    MessageFieldCollection::FixedArray(length) =>
      "  let " +
      field.name +
      " : Array[" +
      nested_type +
      "] = []\n" +
      "  for _ in 0..<" +
      length.to_string() +
      " {\n" +
      "    " +
      field.name +
      ".push(match " +
      nested_type +
      "::read_cdr(reader) {\n" +
      "      Ok(value) => value\n" +
      "      Err(message) => return Err(message)\n" +
      "    })\n" +
      "  }\n"
    MessageFieldCollection::Sequence =>
      rosidl_generate_nested_sequence_reader(field, nested_type, None)
    MessageFieldCollection::BoundedSequence(bound) =>
      rosidl_generate_nested_sequence_reader(field, nested_type, Some(bound))
  }
}

///|
fn rosidl_generate_nested_sequence_reader(
  field : MessageField,
  nested_type : String,
  bound : Int?,
) -> String {
  let mut output = "  let " +
    field.name +
    "_length = match reader.read_u32() {\n" +
    "    Ok(value) => value.reinterpret_as_int()\n" +
    "    Err(message) => return Err(message)\n" +
    "  }\n"
  match bound {
    None =>
      output += "  if " +
        field.name +
        "_length < 0 {\n" +
        "    return Err(\"generated ROS sequence is truncated\")\n" +
        "  }\n"
    Some(value) =>
      output += "  if " +
        field.name +
        "_length < 0 || " +
        field.name +
        "_length > " +
        value.to_string() +
        " {\n" +
        "    return Err(\"generated ROS bounded sequence exceeds its bound\")\n" +
        "  }\n"
  }
  output += "  if " +
    field.name +
    "_length > reader.remaining() {\n" +
    "    return Err(\"generated ROS sequence is truncated\")\n" +
    "  }\n" +
    "  let " +
    field.name +
    " : Array[" +
    nested_type +
    "] = []\n" +
    "  for _ in 0..<" +
    field.name +
    "_length {\n" +
    "    " +
    field.name +
    ".push(match " +
    nested_type +
    "::read_cdr(reader) {\n" +
    "      Ok(value) => value\n" +
    "      Err(message) => return Err(message)\n" +
    "    })\n" +
    "  }\n"
  output
}

///|
fn rosidl_without_comment(line : String) -> String {
  let parts = line.split("#").collect()
  parts[0].to_owned()
}

///|
fn rosidl_trim(value : String) -> String {
  let bytes = @utf8.encode(value)
  let mut start = 0
  let mut end = bytes.length()
  while start < end && rosidl_space(bytes[start]) {
    start += 1
  }
  while end > start && rosidl_space(bytes[end - 1]) {
    end -= 1
  }
  @utf8.decode(bytes[start:end]) catch {
    _ => ""
  }
}

///|
fn rosidl_space(value : Byte) -> Bool {
  value == 9 || value == 10 || value == 13 || value == 32
}

///|
fn rosidl_identifier(value : String) -> Bool {
  let bytes = @utf8.encode(value)
  if bytes.length() == 0 {
    return false
  }
  for index in 0..<bytes.length() {
    let byte = bytes[index]
    let is_letter = (byte >= 65 && byte <= 90) ||
      (byte >= 97 && byte <= 122) ||
      byte == 95
    let is_digit = byte >= 48 && byte <= 57
    if index == 0 {
      if !is_letter {
        return false
      }
    } else if !is_letter && !is_digit {
      return false
    }
  }
  true
}

///|
fn rosidl_type_reference_name(value : String) -> Bool {
  let parts = value.split("/").collect()
  if parts.length() == 1 {
    return rosidl_identifier(value)
  }
  if parts.length() == 2 {
    return rosidl_identifier(parts[0].to_owned()) &&
      rosidl_identifier(parts[1].to_owned())
  }
  if parts.length() != 3 ||
    (parts[1] != "msg" && parts[1] != "srv") {
    return false
  }
  rosidl_identifier(parts[0].to_owned()) &&
  rosidl_identifier(parts[1].to_owned()) &&
  rosidl_identifier(parts[2].to_owned())
}

///|
fn rosidl_moon_type_reference_name(value : String) -> Bool {
  if rosidl_identifier(value) {
    return true
  }
  let parts = value.split(".").collect()
  if parts.length() != 2 {
    return false
  }
  let package_alias = parts[0].to_owned()
  if package_alias.length() <= 1 || package_alias[0] != '@' {
    return false
  }
  rosidl_identifier(package_alias[1:].to_owned()) &&
  rosidl_identifier(parts[1].to_owned())
}

///|
fn rosidl_moon_type(type_name : String) -> Result[String, String] {
  match type_name {
    "bool" => Ok("Bool")
    "byte" => Ok("Byte")
    "char" => Ok("Int")
    "int8" => Ok("Int")
    "uint8" => Ok("Byte")
    "int16" => Ok("Int")
    "uint16" => Ok("UInt")
    "int32" => Ok("Int")
    "uint32" => Ok("UInt")
    "int64" => Ok("Int64")
    "uint64" => Ok("UInt64")
    "float32" => Ok("Float")
    "float64" => Ok("Double")
    "string" => Ok("String")
    _ => Err("unsupported ROS message field type: " + type_name)
  }
}

///|
fn rosidl_moon_type_for_field(
  type_name : String,
  nested_types : Array[MessageTypeReference],
) -> Result[String, String] {
  match rosidl_moon_type(type_name) {
    Ok(value) => Ok(value)
    Err(message) => {
      for nested_type in nested_types {
        if rosidl_type_names_match(nested_type.ros_name, type_name) {
          return Ok(nested_type.moon_name)
        }
      }
      Err(message)
    }
  }
}

///|
fn rosidl_type_names_match(left : String, right : String) -> Bool {
  if left == right {
    return true
  }
  let left_parts = left.split("/").collect()
  let right_parts = right.split("/").collect()
  if left_parts.length() == 2 {
    if right_parts.length() == 3 && right_parts[1] == "msg" {
      return left_parts[0] == right_parts[0] && left_parts[1] == right_parts[2]
    }
  }
  if right_parts.length() == 2 {
    if left_parts.length() == 3 && left_parts[1] == "msg" {
      return right_parts[0] == left_parts[0] && right_parts[1] == left_parts[2]
    }
  }
  false
}

///|
fn rosidl_constant_literal(
  type_name : String,
  value : String,
) -> Result[String, String] {
  match type_name {
    "bool" =>
      if value == "true" || value == "false" {
        Ok(value)
      } else {
        Err("ROS bool constants must be true or false")
      }
    "string" => {
      let bytes = @utf8.encode(value)
      if bytes.length() >= 2 &&
        bytes[0] == b'"' &&
        bytes[bytes.length() - 1] == b'"' {
        Ok(value)
      } else {
        Err("ROS string constants must use double quotes")
      }
    }
    "float32" => {
      if !rosidl_numeric_literal(value, true) {
        return Err("ROS float constants must be numeric")
      }
      if value[value.length() - 1] == 'F' {
        Ok(value)
      } else {
        Ok(value + "F")
      }
    }
    "float64" =>
      if rosidl_numeric_literal(value, true) {
        Ok(value)
      } else {
        Err("ROS float constants must be numeric")
      }
    "int64" =>
      if rosidl_numeric_literal(value, false) {
        Ok(value + "L")
      } else {
        Err("ROS integer constants must be numeric")
      }
    "uint64" =>
      if rosidl_numeric_literal(value, false) {
        Ok(value + "UL")
      } else {
        Err("ROS integer constants must be numeric")
      }
    "byte"
    | "char"
    | "int8"
    | "uint8"
    | "int16"
    | "uint16"
    | "int32"
    | "uint32" =>
      if rosidl_numeric_literal(value, false) {
        Ok(value)
      } else {
        Err("ROS integer constants must be numeric")
      }
    _ => Err("unsupported ROS constant type: " + type_name)
  }
}

///|
fn rosidl_numeric_literal(value : String, allow_float : Bool) -> Bool {
  let bytes = @utf8.encode(value)
  if bytes.length() == 0 {
    return false
  }
  let mut has_digit = false
  let mut has_dot = false
  for index in 0..<bytes.length() {
    let byte = bytes[index]
    if byte >= 48 && byte <= 57 {
      has_digit = true
    } else if byte == b'-' && index == 0 {
      continue
    } else if allow_float && byte == b'.' && !has_dot {
      has_dot = true
    } else {
      return false
    }
  }
  has_digit
}

///|
fn rosidl_writer_method(type_name : String) -> String {
  match type_name {
    "bool" => "write_bool"
    "byte" => "write_u8"
    "char" => "write_i8"
    "int8" => "write_i8"
    "uint8" => "write_u8"
    "int16" => "write_i16_int"
    "uint16" => "write_u16_uint"
    "int32" => "write_i32"
    "uint32" => "write_u32"
    "int64" => "write_i64"
    "uint64" => "write_u64"
    "float32" => "write_f32"
    "float64" => "write_f64"
    "string" => "write_string"
    _ => ""
  }
}

///|
fn rosidl_reader_method(type_name : String) -> String {
  match type_name {
    "bool" => "read_bool"
    "byte" => "read_u8"
    "char" => "read_i8"
    "int8" => "read_i8"
    "uint8" => "read_u8"
    "int16" => "read_i16"
    "uint16" => "read_u16"
    "int32" => "read_i32"
    "uint32" => "read_u32"
    "int64" => "read_i64"
    "uint64" => "read_u64"
    "float32" => "read_f32"
    "float64" => "read_f64"
    "string" => "read_string"
    _ => ""
  }
}
