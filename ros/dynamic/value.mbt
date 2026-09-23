///|
/// A dynamically decoded ROS message value.
pub enum Value {
  BoolValue(Bool)
  SignedValue(Int64)
  UnsignedValue(UInt64)
  FloatValue(Double)
  StringValue(String)
  ArrayValue(Array[Value])
  ObjectValue(Array[(String, Value)])
} derive(Eq, Debug)

///|
/// Decode one serialized ROS message using its installed interface definition.
pub fn decode(
  schema : @introspection.MessageSchema,
  payload : Bytes,
) -> Result[Value, String] {
  let reader = match @cdr.Reader::from_bytes(payload) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value = match decode_definition(schema, schema.root(), reader, 0) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if !reader.remaining_is_zero_padding(4) {
    return Err("trailing bytes after ROS message")
  }
  Ok(value)
}

///|
fn decode_definition(
  schema : @introspection.MessageSchema,
  definition : @rosidl.MessageDefinition,
  reader : @cdr.Reader,
  depth : Int,
) -> Result[Value, String] {
  if depth > 128 {
    return Err("ROS message nesting exceeds 128 levels")
  }
  let values : Array[(String, Value)] = []
  for field in definition.fields() {
    let value = match decode_field(schema, definition, field, reader, depth) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    values.push((field.name(), value))
  }
  Ok(ObjectValue(values))
}

///|
fn decode_field(
  schema : @introspection.MessageSchema,
  owner : @rosidl.MessageDefinition,
  field : @rosidl.MessageField,
  reader : @cdr.Reader,
  depth : Int,
) -> Result[Value, String] {
  let collection = field.collection()
  match collection.fixed_array_length() {
    Some(length) => {
      let values : Array[Value] = []
      for _ in 0..<length {
        match decode_scalar(schema, owner, field, reader, depth + 1) {
          Ok(value) => values.push(value)
          Err(message) => return Err(message)
        }
      }
      Ok(ArrayValue(values))
    }
    None if collection.is_sequence() => {
      let length = match reader.read_u32() {
        Ok(value) => value.reinterpret_as_int()
        Err(message) => return Err(message)
      }
      if length < 0 || length > 1_000_000 {
        return Err("ROS sequence length is outside the supported range")
      }
      match collection.sequence_bound() {
        Some(bound) if length > bound =>
          return Err("ROS sequence exceeds its declared bound")
        _ => ()
      }
      let values : Array[Value] = []
      for _ in 0..<length {
        match decode_scalar(schema, owner, field, reader, depth + 1) {
          Ok(value) => values.push(value)
          Err(message) => return Err(message)
        }
      }
      Ok(ArrayValue(values))
    }
    None => decode_scalar(schema, owner, field, reader, depth + 1)
  }
}

///|
fn decode_scalar(
  schema : @introspection.MessageSchema,
  owner : @rosidl.MessageDefinition,
  field : @rosidl.MessageField,
  reader : @cdr.Reader,
  depth : Int,
) -> Result[Value, String] {
  match field.type_name() {
    "bool" => reader.read_bool().map(fn(value) { BoolValue(value) })
    "int8" => reader.read_i8().map(fn(value) { SignedValue(value.to_int64()) })
    "int16" =>
      reader.read_i16().map(fn(value) { SignedValue(value.to_int64()) })
    "int32" =>
      reader.read_i32().map(fn(value) { SignedValue(value.to_int64()) })
    "int64" => reader.read_i64().map(fn(value) { SignedValue(value) })
    "byte" | "char" | "uint8" =>
      reader
      .read_u8()
      .map(fn(value) { UnsignedValue(value.to_int().to_uint64()) })
    "uint16" =>
      reader.read_u16().map(fn(value) { UnsignedValue(value.to_uint64()) })
    "uint32" =>
      reader.read_u32().map(fn(value) { UnsignedValue(value.to_uint64()) })
    "uint64" => reader.read_u64().map(fn(value) { UnsignedValue(value) })
    "float32" =>
      reader.read_f32().map(fn(value) { FloatValue(value.to_double()) })
    "float64" => reader.read_f64().map(fn(value) { FloatValue(value) })
    "string" => {
      let value = match field.string_upper_bound() {
        Some(bound) => reader.read_bounded_string(bound)
        None => reader.read_string()
      }
      value.map(fn(value) { StringValue(value) })
    }
    "wstring" => {
      let value = match field.string_upper_bound() {
        Some(bound) => reader.read_bounded_wstring(bound)
        None => reader.read_wstring()
      }
      value.map(fn(value) { StringValue(value) })
    }
    type_name => {
      let (package_name, nested_name) = match
        dynamic_nested_type(owner.package_name(), type_name) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let nested = match schema.find(package_name, nested_name) {
        Some(value) => value
        None =>
          return Err("missing nested ROS message definition: " + type_name)
      }
      decode_definition(schema, nested, reader, depth + 1)
    }
  }
}

///|
fn dynamic_nested_type(
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
/// Format a dynamically decoded ROS message as YAML.
pub fn to_yaml(value : Value) -> Result[String, String] {
  match value {
    ObjectValue(fields) => {
      if fields.length() == 0 {
        return Ok("{}\n")
      }
      let lines : Array[String] = []
      for (name, field_value) in fields {
        append_yaml_field(lines, name, field_value, 0)
      }
      Ok(lines.join("\n") + "\n")
    }
    _ => Err("a ROS message root must be a mapping")
  }
}

///|
fn append_yaml_field(
  lines : Array[String],
  name : String,
  value : Value,
  indent : Int,
) -> Unit {
  let prefix = dynamic_indent(indent) + name + ":"
  match value {
    ObjectValue(fields) => {
      if fields.length() == 0 {
        lines.push(prefix + " {}")
        return
      }
      lines.push(prefix)
      for (child_name, child_value) in fields {
        append_yaml_field(lines, child_name, child_value, indent + 2)
      }
    }
    ArrayValue(values) =>
      if values.length() == 0 {
        lines.push(prefix + " []")
      } else if dynamic_array_is_scalar(values) {
        lines.push(prefix + " " + dynamic_yaml_array(values))
      } else {
        lines.push(prefix)
        let count = if values.length() > 128 { 128 } else { values.length() }
        for index in 0..<count {
          let item = values[index]
          match item {
            ObjectValue(fields) =>
              if fields.length() == 0 {
                lines.push(dynamic_indent(indent + 2) + "- {}")
              } else {
                let first_name = fields[0].0
                let first_value = fields[0].1
                append_yaml_sequence_object_first(
                  lines,
                  first_name,
                  first_value,
                  indent + 2,
                )
                for field_index in 1..<fields.length() {
                  let (child_name, child_value) = fields[field_index]
                  append_yaml_field(lines, child_name, child_value, indent + 4)
                }
              }
            _ =>
              lines.push(
                dynamic_indent(indent + 2) + "- " + dynamic_yaml_scalar(item),
              )
          }
        }
        if count < values.length() {
          lines.push(dynamic_indent(indent + 2) + "- ...")
        }
      }
    _ => lines.push(prefix + " " + dynamic_yaml_scalar(value))
  }
}

///|
fn append_yaml_sequence_object_first(
  lines : Array[String],
  name : String,
  value : Value,
  indent : Int,
) -> Unit {
  match value {
    ObjectValue(fields) => {
      lines.push(dynamic_indent(indent) + "- " + name + ":")
      for (child_name, child_value) in fields {
        append_yaml_field(lines, child_name, child_value, indent + 4)
      }
    }
    ArrayValue(values) =>
      lines.push(
        dynamic_indent(indent) + "- " + name + ": " + dynamic_yaml_array(values),
      )
    _ =>
      lines.push(
        dynamic_indent(indent) + "- " + name + ": " + dynamic_yaml_scalar(value),
      )
  }
}

///|
fn dynamic_array_is_scalar(values : Array[Value]) -> Bool {
  for value in values {
    match value {
      ObjectValue(_) | ArrayValue(_) => return false
      _ => ()
    }
  }
  true
}

///|
fn dynamic_yaml_array(values : Array[Value]) -> String {
  let count = if values.length() > 128 { 128 } else { values.length() }
  let mut output = "["
  for index in 0..<count {
    if index > 0 {
      output += ", "
    }
    output += dynamic_yaml_scalar(values[index])
  }
  if count < values.length() {
    if count > 0 {
      output += ", "
    }
    output += "..."
  }
  output + "]"
}

///|
fn dynamic_yaml_scalar(value : Value) -> String {
  match value {
    BoolValue(value) => value.to_string()
    SignedValue(value) => value.to_string()
    UnsignedValue(value) => value.to_string()
    FloatValue(value) => value.to_string()
    StringValue(value) => Json::string(value).stringify()
    _ => "null"
  }
}

///|
fn dynamic_indent(length : Int) -> String {
  let mut output = ""
  for _ in 0..<length {
    output += " "
  }
  output
}
