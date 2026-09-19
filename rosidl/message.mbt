///|
/// A scalar field in a ROS `.msg` definition.
pub struct MessageField {
  type_name : String
  name : String
} derive(Eq, Debug)

///|
/// A parsed ROS message definition containing supported scalar fields.
pub struct MessageDefinition {
  package_name : String
  interface_namespace : String
  type_name : String
  fields : Array[MessageField]
} derive(Eq, Debug)

///|
/// Create a message field descriptor.
pub fn MessageField::new(type_name : String, name : String) -> MessageField {
  { type_name, name, }
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
  }
  Ok({ package_name, interface_namespace, type_name, fields, })
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
/// Parse the scalar-field subset of a ROS `.msg` definition.
///
/// Blank lines and `#` comments are ignored. Array, sequence, constant, and
/// nested message fields are rejected until their generated CDR representation
/// is implemented.
pub fn parse_message(
  package_name : String,
  interface_namespace : String,
  type_name : String,
  source : String,
) -> Result[MessageDefinition, String] {
  let fields : Array[MessageField] = []
  for raw_line in source.split("\n") {
    let line = rosidl_trim(rosidl_without_comment(raw_line.to_owned()))
    if line.length() == 0 {
      continue
    }
    if line.split("=").collect().length() > 1 {
      return Err("ROS message constants are not supported by this generator")
    }
    let words : Array[String] = []
    for raw_word in line.split(" ") {
      let word = rosidl_trim(raw_word.to_owned())
      if word.length() > 0 {
        words.push(word)
      }
    }
    if words.length() != 2 {
      return Err("ROS message fields must have exactly a type and a name")
    }
    if words[0].split("[").collect().length() > 1 ||
      words[0].split("]").collect().length() > 1 {
      return Err(
        "ROS message arrays and sequences are not supported by this generator",
      )
    }
    match rosidl_moon_type(words[0]) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    if !rosidl_identifier(words[1]) {
      return Err("ROS message field names must be identifiers")
    }
    fields.push(MessageField::new(words[0], words[1]))
  }
  MessageDefinition::new(package_name, interface_namespace, type_name, fields)
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
      rosidl_moon_type(field.type_name).unwrap() +
      "\n"
  }
  output += "} derive(Eq, Debug)\n\n"
  output += "///|\n"
  output += "pub fn " + self.type_name + "::new(\n"
  for field in self.fields {
    output += "  " +
      field.name +
      " : " +
      rosidl_moon_type(field.type_name).unwrap() +
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
      rosidl_moon_type(field.type_name).unwrap() +
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
    output += "  writer." +
      rosidl_writer_method(field.type_name) +
      "(self." +
      field.name +
      ")\n"
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
    output += "  let " +
      field.name +
      " = match reader." +
      rosidl_reader_method(field.type_name) +
      "() {\n"
    output += "    Ok(value) => value\n"
    output += "    Err(message) => return Err(message)\n"
    output += "  }\n"
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
