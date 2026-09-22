///|
/// Parse the primitive-field subset of a ROS `.msg` definition.
///
/// Blank lines and `#` comments are ignored. Fixed arrays (`type[N]`),
/// unbounded sequences (`type[]`), bounded sequences (`type[<=N]`), bounded
/// strings (`string<=N` / `wstring<=N`), and scalar constants are supported.
/// Nested message fields can be enabled with `parse_message_with_types`.
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
    let assignment_index = rosidl_assignment_index(line)
    if assignment_index >= 0 {
      let bytes = @utf8.encode(line)
      let declaration_source = @utf8.decode(bytes[:assignment_index]) catch {
        _ => ""
      }
      let declaration = rosidl_words(declaration_source)
      if declaration.length() != 2 {
        return Err("ROS message constants must have a type and a name")
      }
      let value = rosidl_trim(
        @utf8.decode(bytes[assignment_index + 1:]) catch {
          _ => ""
        },
      )
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
    if words.length() < 2 {
      return Err("ROS message fields must have a type and a name")
    }
    let (base_type, string_upper_bound, collection) = match
      rosidl_parse_field_type(words[0]) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    if !rosidl_identifier(words[1]) {
      return Err("ROS message field names must be identifiers")
    }
    let mut field = MessageField::new(base_type, words[1]).with_collection(
      collection,
    )
    field = match string_upper_bound {
      Some(bound) => field.with_string_upper_bound(bound)
      None => field
    }
    let default_source = rosidl_text_after_words(line, 2)
    if default_source.length() > 0 {
      let default_value = match
        rosidl_field_default_literal(
          base_type, string_upper_bound, collection, default_source,
        ) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      field = field.with_default_value(default_value)
    }
    fields.push(field)
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
  let (request_source, response_source) = match
    rosidl_service_request_response(source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let request = match
    parse_message_with_types(
      package_name,
      "srv",
      service_name + "_Request",
      request_source,
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
      response_source,
      nested_types,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  ServiceDefinition::new(package_name, service_name, request, response)
}

///|
fn rosidl_service_request_response(
  source : String,
) -> Result[(String, String), String] {
  let mut request_source = ""
  let mut response_source = ""
  let mut has_separator = false
  for raw_line in source.split("\n") {
    if rosidl_trim(raw_line.to_owned()) == "---" {
      if has_separator {
        return Err("ROS service definitions must contain one --- separator")
      }
      has_separator = true
      continue
    }
    if has_separator {
      response_source += raw_line.to_owned() + "\n"
    } else {
      request_source += raw_line.to_owned() + "\n"
    }
  }
  if !has_separator {
    return Err("ROS service definitions must contain one --- separator")
  }
  Ok((request_source, response_source))
}

///|
fn rosidl_words(line : String) -> Array[String] {
  let words : Array[String] = []
  let bytes = @utf8.encode(line)
  let mut word_start = -1
  for index in 0..<bytes.length() {
    if rosidl_space(bytes[index]) {
      if word_start >= 0 {
        words.push(@utf8.decode(bytes[word_start:index]) catch { _ => "" })
        word_start = -1
      }
    } else if word_start < 0 {
      word_start = index
    }
  }
  if word_start >= 0 {
    words.push(@utf8.decode(bytes[word_start:]) catch { _ => "" })
  }
  words
}

///|
/// Return the trimmed suffix after a fixed number of whitespace-delimited words.
fn rosidl_text_after_words(line : String, word_count : Int) -> String {
  let bytes = @utf8.encode(line)
  let mut completed_words = 0
  let mut in_word = false
  for index in 0..<bytes.length() {
    if rosidl_space(bytes[index]) {
      if in_word {
        completed_words += 1
        in_word = false
        if completed_words == word_count {
          return rosidl_trim(@utf8.decode(bytes[index:]) catch { _ => "" })
        }
      }
    } else if !in_word {
      in_word = true
    }
  }
  ""
}

///|
/// Find an assignment separator before any field default value.
fn rosidl_assignment_index(line : String) -> Int {
  let bytes = @utf8.encode(line)
  for index in 0..<bytes.length() {
    if bytes[index] == b'=' && (index == 0 || bytes[index - 1] != b'<') {
      let declaration_source = @utf8.decode(bytes[:index]) catch { _ => "" }
      if rosidl_words(declaration_source).length() == 2 {
        return index
      }
    }
  }
  -1
}

///|
fn rosidl_parse_field_type(
  type_spec : String,
) -> Result[(String, Int?, MessageFieldCollection), String] {
  let parts = type_spec.split("[").collect()
  if parts.length() == 1 {
    let (base_type, string_upper_bound) = match
      rosidl_parse_base_field_type(parts[0].to_owned()) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    Ok((base_type, string_upper_bound, Scalar))
  } else if parts.length() != 2 {
    Err("ROS message field type has an invalid collection suffix")
  } else {
    let (base_type, string_upper_bound) = match
      rosidl_parse_base_field_type(parts[0].to_owned()) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let suffix = parts[1].to_owned()
    if suffix.length() == 0 || suffix[suffix.length() - 1] != ']' {
      return Err("ROS message collection type must end with ]")
    }
    let inner = suffix[0:suffix.length() - 1].to_owned()
    if inner.length() == 0 {
      Ok((base_type, string_upper_bound, Sequence))
    } else if inner[0] == '<' {
      if inner.length() <= 2 || inner[1] != '=' {
        return Err("ROS bounded sequence must use the <=N form")
      }
      let bound = match rosidl_positive_int(inner[2:].to_owned()) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      Ok((base_type, string_upper_bound, BoundedSequence(bound)))
    } else {
      let length = match rosidl_positive_int(inner) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      Ok((base_type, string_upper_bound, FixedArray(length)))
    }
  }
}

///|
fn rosidl_parse_base_field_type(
  type_spec : String,
) -> Result[(String, Int?), String] {
  let parts = type_spec.split("<=").collect()
  if parts.length() == 1 {
    return Ok((type_spec, None))
  }
  if parts.length() != 2 || (parts[0] != "string" && parts[0] != "wstring") {
    return Err("ROS bounded strings must use the string<=N or wstring<=N form")
  }
  let bound = match rosidl_positive_int(parts[1].to_owned()) {
    Ok(value) => value
    Err(_) => return Err("ROS string upper bounds must be positive integers")
  }
  Ok((parts[0].to_owned(), Some(bound)))
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
fn rosidl_constant_identifier(value : String) -> Bool {
  let bytes = @utf8.encode(value)
  if bytes.length() == 0 || bytes[0] < 65 || bytes[0] > 90 {
    return false
  }
  for index in 1..<bytes.length() {
    let byte = bytes[index]
    let is_uppercase = byte >= 65 && byte <= 90
    let is_digit = byte >= 48 && byte <= 57
    if is_uppercase || is_digit {
      continue
    }
    if byte != 95 || index == bytes.length() - 1 || bytes[index - 1] == 95 {
      return false
    }
    let next = bytes[index + 1]
    if (next < 65 || next > 90) && (next < 48 || next > 57) {
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
  if parts.length() != 3 || (parts[1] != "msg" && parts[1] != "srv") {
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
    "char" => Ok("Byte")
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
    "string" | "wstring" => Ok("String")
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
