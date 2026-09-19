///|
/// The collection shape of a ROS message field.
pub(all) enum MessageFieldCollection {
  Scalar
  FixedArray(Int)
  Sequence
} derive(Eq, Debug)

///|
/// A field in a ROS `.msg` definition.
pub struct MessageField {
  type_name : String
  name : String
  collection : MessageFieldCollection
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
  if !rosidl_identifier(package_name) ||
    !rosidl_identifier(interface_namespace) ||
    !rosidl_identifier(type_name) {
    return Err("ROS message package, namespace, and type must be identifiers")
  }
  for field in fields {
    if !rosidl_identifier(field.name) {
      return Err("ROS message field names must be identifiers")
    }
    match rosidl_moon_type(field.type_name) {
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
    }
  }
  Ok({ package_name, interface_namespace, type_name, fields, constants: [], })
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
/// Parse the primitive-field subset of a ROS `.msg` definition.
///
/// Blank lines and `#` comments are ignored. Fixed arrays (`type[N]`) and
/// unbounded sequences (`type[]`) and scalar constants are supported. Bounded
/// sequences and nested message fields are rejected until their generated CDR
/// representation is implemented.
pub fn parse_message(
  package_name : String,
  interface_namespace : String,
  type_name : String,
  source : String,
) -> Result[MessageDefinition, String] {
  let fields : Array[MessageField] = []
  let constants : Array[MessageConstant] = []
  for raw_line in source.split("\n") {
    let line = rosidl_trim(rosidl_without_comment(raw_line.to_owned()))
    if line.length() == 0 {
      continue
    }
    let equal_parts = line.split("=").collect()
    if equal_parts.length() > 1 {
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
    MessageDefinition::new(package_name, interface_namespace, type_name, fields) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  definition.with_constants(constants)
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
    match rosidl_moon_type(parts[0].to_owned()) {
      Ok(_) => Ok((parts[0].to_owned(), MessageFieldCollection::Scalar))
      Err(message) => Err(message)
    }
  } else if parts.length() != 2 {
    Err("ROS message field type has an invalid collection suffix")
  } else {
    let base_type = parts[0].to_owned()
    let suffix = parts[1].to_owned()
    if suffix.length() == 0 || suffix[suffix.length() - 1] != ']' {
      return Err("ROS message collection type must end with ]")
    }
    match rosidl_moon_type(base_type) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    let inner = suffix[0:suffix.length() - 1].to_owned()
    if inner.length() == 0 {
      Ok((base_type, MessageFieldCollection::Sequence))
    } else if inner[0] == '<' {
      Err("bounded ROS message sequences are not supported by this generator")
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
    output += "  " + field.name + " : " + rosidl_field_moon_type(field) + "\n"
  }
  output += "} derive(Eq, Debug)\n\n"
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
    output += "  " + field.name + " : " + rosidl_field_moon_type(field) + ",\n"
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
      rosidl_field_moon_type(field) +
      " {\n"
    output += "  self." + field.name + "\n}\n\n"
  }
  output += "///|\n"
  output += "pub fn " +
    self.type_name +
    "::to_cdr_bytes(self : " +
    self.type_name +
    ") -> Bytes {\n"
  output += "  let writer = @cdr.Writer::new()\n"
  for field in self.fields {
    output += rosidl_generate_writer(field)
  }
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
  for field in self.fields {
    output += rosidl_generate_reader(field)
  }
  output += "  if reader.remaining() != 0 {\n"
  output += "    return Err(\"trailing bytes after generated ROS message\")\n"
  output += "  }\n"
  output += "  Ok(" + self.type_name + "::new(\n"
  for field in self.fields {
    output += "    " + field.name + ",\n"
  }
  output += "  ))\n}\n"
  output
}

///|
fn rosidl_field_moon_type(field : MessageField) -> String {
  let base = rosidl_moon_type(field.type_name).unwrap()
  match field.collection {
    MessageFieldCollection::Scalar => base
    MessageFieldCollection::FixedArray(_) => "Array[" + base + "]"
    MessageFieldCollection::Sequence => "Array[" + base + "]"
  }
}

///|
fn rosidl_generate_writer(field : MessageField) -> String {
  let codec_method = rosidl_writer_method(field.type_name)
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
  }
}

///|
fn rosidl_generate_reader(field : MessageField) -> String {
  let codec_method = rosidl_reader_method(field.type_name)
  let base = rosidl_moon_type(field.type_name).unwrap()
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
  }
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
