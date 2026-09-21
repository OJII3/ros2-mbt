///|
/// Generate request and response MoonBit CDR codecs for a ROS service.
pub fn ServiceDefinition::generate_moonbit(self : ServiceDefinition) -> String {
  let output = self.request.generate_moonbit() +
    "\n" +
    self.response.generate_moonbit()
  match self.type_hash() {
    Ok(type_hash) =>
      output +
      "\n///|\n" +
      "pub const " +
      self.service_name +
      "_TYPE_HASH : String = \"" +
      type_hash +
      "\"\n"
    Err(_) => output
  }
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
      output += "pub const " +
        self.type_name +
        "_TYPE_HASH : String = \"" +
        type_hash +
        "\"\n\n"
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
  output += "///|\n"
  output += "pub fn " +
    self.type_name +
    "::default() -> " +
    self.type_name +
    " {\n"
  for field in self.fields {
    output += rosidl_generate_default_field(field, self.nested_types)
  }
  output += "  " + self.type_name + "::new(\n"
  for field in self.fields {
    output += "    " + field.name + ",\n"
  }
  output += "  )\n}\n\n"
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
    ", writer : @cdr.Writer) -> Result[Unit, String] {\n"
  for field in self.fields {
    output += rosidl_generate_writer(field)
  }
  output += "  Ok(())\n}\n\n"
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
    ") -> Result[Bytes, String] {\n"
  output += "  let writer = @cdr.Writer::new()\n"
  output += "  match self.write_cdr(writer) {\n"
  output += "    Ok(_) => ()\n"
  output += "    Err(message) => return Err(message)\n"
  output += "  }\n"
  output += "  Ok(writer.to_bytes())\n}\n\n"
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
fn rosidl_generate_default_field(
  field : MessageField,
  nested_types : Array[MessageTypeReference],
) -> String {
  let field_type = rosidl_field_moon_type(field, nested_types)
  match field.default_value {
    Some(value) =>
      "  let " + field.name + " : " + field_type + " = " + value + "\n"
    None =>
      match field.collection {
        MessageFieldCollection::Scalar =>
          "  let " +
          field.name +
          " : " +
          field_type +
          " = " +
          rosidl_default_scalar(field, nested_types) +
          "\n"
        MessageFieldCollection::FixedArray(length) =>
          "  let " +
          field.name +
          " : " +
          field_type +
          " = []\n" +
          "  for _ in 0..<" +
          length.to_string() +
          " {\n" +
          "    " +
          field.name +
          ".push(" +
          rosidl_default_scalar(field, nested_types) +
          ")\n" +
          "  }\n"
        MessageFieldCollection::Sequence
        | MessageFieldCollection::BoundedSequence(_) =>
          "  let " + field.name + " : " + field_type + " = []\n"
      }
  }
}

///|
fn rosidl_default_scalar(
  field : MessageField,
  nested_types : Array[MessageTypeReference],
) -> String {
  match field.type_name {
    "bool" => "false"
    "byte"
    | "char"
    | "int8"
    | "uint8"
    | "int16"
    | "uint16"
    | "int32"
    | "uint32" => "0"
    "int64" => "0L"
    "uint64" => "0UL"
    "float32" => "0.0F"
    "float64" => "0.0"
    "string" | "wstring" => "\"\""
    _ =>
      rosidl_moon_type_for_field(field.type_name, nested_types).unwrap() +
      "::default()"
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
      rosidl_generate_writer_call(
        field,
        codec_method,
        "self." + field.name,
        "  ",
      )
    MessageFieldCollection::FixedArray(_) =>
      "  for value in self." +
      field.name +
      " {\n" +
      rosidl_generate_writer_call(field, codec_method, "value", "    ") +
      "  }\n"
    MessageFieldCollection::Sequence =>
      "  writer.write_u32(self." +
      field.name +
      ".length().reinterpret_as_uint())\n" +
      "  for value in self." +
      field.name +
      " {\n" +
      rosidl_generate_writer_call(field, codec_method, "value", "    ") +
      "  }\n"
    MessageFieldCollection::BoundedSequence(bound) =>
      "  if self." +
      field.name +
      ".length() > " +
      bound.to_string() +
      " {\n    return Err(\"generated ROS bounded sequence exceeds its bound\")\n  }\n" +
      "  writer.write_u32(self." +
      field.name +
      ".length().reinterpret_as_uint())\n" +
      "  for value in self." +
      field.name +
      " {\n" +
      rosidl_generate_writer_call(field, codec_method, "value", "    ") +
      "  }\n"
  }
}

///|
fn rosidl_generate_writer_call(
  field : MessageField,
  codec_method : String,
  value : String,
  indent : String,
) -> String {
  let range_check = rosidl_generate_writer_range_check(field, value, indent)
  range_check +
  (match field.string_upper_bound {
    Some(bound) => {
      let bounded_method = if field.type_name == "wstring" {
        "write_bounded_wstring"
      } else {
        "write_bounded_string"
      }
      indent +
      "match writer." +
      bounded_method +
      "(" +
      value +
      ", " +
      bound.to_string() +
      ") {\n" +
      indent +
      "  Ok(_) => ()\n" +
      indent +
      "  Err(message) => return Err(message)\n" +
      indent +
      "}\n"
    }
    None if field.type_name == "wstring" =>
      indent +
      "match writer." +
      codec_method +
      "(" +
      value +
      ") {\n" +
      indent +
      "  Ok(_) => ()\n" +
      indent +
      "  Err(message) => return Err(message)\n" +
      indent +
      "}\n"
    None => indent + "writer." + codec_method + "(" + value + ")\n"
  })
}

///|
fn rosidl_generate_writer_range_check(
  field : MessageField,
  value : String,
  indent : String,
) -> String {
  let condition = match field.type_name {
    "int8" => value + " < -128 || " + value + " > 127"
    "int16" => value + " < -32768 || " + value + " > 32767"
    "uint16" => value + " > 65535U"
    _ => ""
  }
  if condition.length() == 0 {
    return ""
  }
  indent +
  "if " +
  condition +
  " {\n" +
  indent +
  "  return Err(\"generated ROS " +
  field.type_name +
  " value is out of range\")\n" +
  indent +
  "}\n"
}

///|
fn rosidl_generate_reader(
  field : MessageField,
  nested_types : Array[MessageTypeReference],
) -> String {
  let codec_method = rosidl_reader_method(field.type_name)
  let codec_call = match field.string_upper_bound {
    Some(bound) => {
      let bounded_method = if field.type_name == "wstring" {
        "read_bounded_wstring"
      } else {
        "read_bounded_string"
      }
      "reader." + bounded_method + "(" + bound.to_string() + ")"
    }
    None => "reader." + codec_method + "()"
  }
  let base = rosidl_moon_type_for_field(field.type_name, nested_types).unwrap()
  if rosidl_moon_type(field.type_name) is Err(_) {
    return rosidl_generate_nested_reader(field, base)
  }
  match field.collection {
    MessageFieldCollection::Scalar =>
      "  let " +
      field.name +
      " = match " +
      codec_call +
      " {\n" +
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
      ".push(match " +
      codec_call +
      " {\n" +
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
      ".push(match " +
      codec_call +
      " {\n" +
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
      ".push(match " +
      codec_call +
      " {\n" +
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
      rosidl_generate_nested_writer_call("self." + field.name, "  ")
    MessageFieldCollection::FixedArray(_) =>
      "  for value in self." +
      field.name +
      " {\n" +
      rosidl_generate_nested_writer_call("value", "    ") +
      "  }\n"
    MessageFieldCollection::Sequence =>
      "  writer.write_u32(self." +
      field.name +
      ".length().reinterpret_as_uint())\n" +
      "  for value in self." +
      field.name +
      " {\n" +
      rosidl_generate_nested_writer_call("value", "    ") +
      "  }\n"
    MessageFieldCollection::BoundedSequence(bound) =>
      "  if self." +
      field.name +
      ".length() > " +
      bound.to_string() +
      " {\n    return Err(\"generated ROS bounded sequence exceeds its bound\")\n  }\n" +
      "  writer.write_u32(self." +
      field.name +
      ".length().reinterpret_as_uint())\n" +
      "  for value in self." +
      field.name +
      " {\n" +
      rosidl_generate_nested_writer_call("value", "    ") +
      "  }\n"
  }
}

///|
fn rosidl_generate_nested_writer_call(
  value : String,
  indent : String,
) -> String {
  indent +
  "match " +
  value +
  ".write_cdr(writer) {\n" +
  indent +
  "  Ok(_) => ()\n" +
  indent +
  "  Err(message) => return Err(message)\n" +
  indent +
  "}\n"
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
