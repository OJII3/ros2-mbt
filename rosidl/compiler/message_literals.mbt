///|
fn rosidl_constant_literal(
  type_name : String,
  value : String,
) -> Result[String, String] {
  match type_name {
    "bool" =>
      match rosidl_ascii_lower(value) {
        "true" | "1" => Ok("true")
        "false" | "0" => Ok("false")
        _ => Err("ROS bool constants must be true, false, 1, or 0")
      }
    "string" | "wstring" => rosidl_string_constant_literal(value)
    "float32" => {
      if !rosidl_float_literal(value) {
        return Err("ROS float constants must be numeric")
      }
      Ok(rosidl_normalize_float_literal(value) + "F")
    }
    "float64" =>
      if rosidl_float_literal(value) {
        Ok(rosidl_normalize_float_literal(value))
      } else {
        Err("ROS float constants must be numeric")
      }
    "int8" | "int16" | "int32" | "int64" =>
      rosidl_signed_constant_literal(type_name, value)
    "byte" | "char" | "uint8" | "uint16" | "uint32" | "uint64" =>
      rosidl_unsigned_constant_literal(type_name, value)
    _ => Err("unsupported ROS constant type: " + type_name)
  }
}

///|
fn rosidl_field_default_literal(
  type_name : String,
  string_upper_bound : Int?,
  collection : MessageFieldCollection,
  value : String,
) -> Result[String, String] {
  match collection {
    MessageFieldCollection::Scalar =>
      rosidl_field_scalar_default_literal(type_name, string_upper_bound, value)
    MessageFieldCollection::FixedArray(_)
    | MessageFieldCollection::Sequence
    | MessageFieldCollection::BoundedSequence(_) => {
      let elements = match rosidl_array_default_elements(type_name, value) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      match collection {
        MessageFieldCollection::FixedArray(expected) if elements.length() !=
          expected =>
          return Err("ROS fixed-array defaults must match the declared length")
        MessageFieldCollection::BoundedSequence(maximum) if elements.length() >
          maximum =>
          return Err("ROS bounded-sequence defaults exceed their bound")
        _ => ()
      }
      let mut literal = "["
      for index in 0..<elements.length() {
        if index > 0 {
          literal += ", "
        }
        literal += match
          rosidl_field_scalar_default_literal(
            type_name,
            string_upper_bound,
            elements[index],
          ) {
          Ok(value) => value
          Err(message) => return Err(message)
        }
      }
      Ok(literal + "]")
    }
  }
}

///|
fn rosidl_array_default_elements(
  type_name : String,
  value : String,
) -> Result[Array[String], String] {
  let bytes = @utf8.encode(value)
  if bytes.length() < 2 || bytes[0] != b'[' || bytes[bytes.length() - 1] != b']' {
    return Err("ROS array defaults must be enclosed in brackets")
  }
  let end = bytes.length() - 1
  let elements : Array[String] = []
  if end == 1 {
    return Ok(elements)
  }
  let is_string = type_name == "string" || type_name == "wstring"
  let mut quote = 0
  let mut escaped = false
  let mut element_start = 1
  for index in 1..<end {
    let byte = bytes[index]
    if quote != 0 {
      if escaped {
        escaped = false
      } else if byte == b'\\' {
        escaped = true
      } else if byte.to_int() == quote {
        quote = 0
      }
    } else if is_string && (byte == b'\'' || byte == b'"') {
      quote = byte.to_int()
    } else if byte == b',' {
      elements.push(
        rosidl_trim(@utf8.decode(bytes[element_start:index]) catch { _ => "" }),
      )
      element_start = index + 1
    }
  }
  if quote != 0 {
    return Err("ROS string-array defaults contain an unterminated quote")
  }
  elements.push(
    rosidl_trim(@utf8.decode(bytes[element_start:end]) catch { _ => "" }),
  )
  Ok(elements)
}

///|
fn rosidl_field_scalar_default_literal(
  type_name : String,
  string_upper_bound : Int?,
  value : String,
) -> Result[String, String] {
  if type_name == "string" || type_name == "wstring" {
    let decoded = match rosidl_string_constant_value(value) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    match string_upper_bound {
      Some(bound) if (if type_name == "wstring" {
          rosidl_utf16_unit_count(decoded)
        } else {
          rosidl_utf8_character_count(decoded)
        }) >
        bound => return Err("ROS string defaults exceed their declared bound")
      _ => ()
    }
    return Ok(rosidl_moonbit_string_literal(decoded))
  }
  rosidl_constant_literal(type_name, value)
}

///|
fn rosidl_utf8_character_count(value : String) -> Int {
  let mut count = 0
  for byte in @utf8.encode(value) {
    if byte < 0x80 || byte > 0xBF {
      count += 1
    }
  }
  count
}

///|
fn rosidl_utf16_unit_count(value : String) -> Int {
  let mut count = 0
  for byte in @utf8.encode(value) {
    if byte < 0x80 || byte > 0xBF {
      count += if byte >= 0xF0 { 2 } else { 1 }
    }
  }
  count
}

///|
fn rosidl_ascii_lower(value : String) -> String {
  let bytes = @utf8.encode(value)
  let mut result = ""
  let mut segment_start = 0
  for index in 0..<bytes.length() {
    let byte = bytes[index]
    if byte >= 65 && byte <= 90 {
      result += @utf8.decode(bytes[segment_start:index]) catch { _ => "" }
      result += @utf8.decode(
        Bytes::from_array([(byte.to_int() + 32).to_byte()]),
      ) catch {
        _ => ""
      }
      segment_start = index + 1
    }
  }
  result + (@utf8.decode(bytes[segment_start:]) catch { _ => "" })
}

///|
fn rosidl_string_constant_literal(value : String) -> Result[String, String] {
  match rosidl_string_constant_value(value) {
    Ok(value) => Ok(rosidl_moonbit_string_literal(value))
    Err(message) => Err(message)
  }
}

///|
fn rosidl_string_constant_value(value : String) -> Result[String, String] {
  let bytes = @utf8.encode(value)
  let quoted = bytes.length() >= 2 &&
    (
      (bytes[0] == b'"' && bytes[bytes.length() - 1] == b'"') ||
      (bytes[0] == b'\'' && bytes[bytes.length() - 1] == b'\'')
    )
  let string_value = if !quoted {
    value
  } else {
    let quote = bytes[0]
    let end = bytes.length() - 1
    let mut result = ""
    let mut segment_start = 1
    let mut index = 1
    while index < end {
      if bytes[index] == quote {
        if index == 1 || bytes[index - 1] != b'\\' {
          return Err("ROS string constants contain an unescaped quote")
        }
      }
      if bytes[index] == b'\\' && index + 1 < end && bytes[index + 1] == quote {
        result += @utf8.decode(bytes[segment_start:index]) catch { _ => "" }
        result += @utf8.decode(Bytes::from_array([quote])) catch { _ => "" }
        index += 2
        segment_start = index
      } else {
        index += 1
      }
    }
    result + (@utf8.decode(bytes[segment_start:end]) catch { _ => "" })
  }
  Ok(string_value)
}

///|
fn rosidl_moonbit_string_literal(value : String) -> String {
  let bytes = @utf8.encode(value)
  let mut result = "\""
  let mut segment_start = 0
  for index in 0..<bytes.length() {
    let escape = match bytes[index] {
      b'\\' => "\\\\"
      b'"' => "\\\""
      b'\n' => "\\n"
      b'\r' => "\\r"
      b'\t' => "\\t"
      _ => ""
    }
    if escape.length() > 0 {
      result += @utf8.decode(bytes[segment_start:index]) catch { _ => "" }
      result += escape
      segment_start = index + 1
    }
  }
  result + (@utf8.decode(bytes[segment_start:]) catch { _ => "" }) + "\""
}

///|
fn rosidl_signed_constant_literal(
  type_name : String,
  value : String,
) -> Result[String, String] {
  let parsed : Int64 = @string.from_str(value) catch {
    _ => return Err("ROS " + type_name + " constants must be valid integers")
  }
  let in_range = match type_name {
    "int8" => parsed >= -128L && parsed <= 127L
    "int16" => parsed >= -32768L && parsed <= 32767L
    "int32" => parsed >= -2147483648L && parsed <= 2147483647L
    "int64" => true
    _ => false
  }
  if !in_range {
    return Err("ROS " + type_name + " constant is out of range")
  }
  let literal = parsed.to_string()
  if type_name == "int64" {
    Ok(literal + "L")
  } else {
    Ok(literal)
  }
}

///|
fn rosidl_unsigned_constant_literal(
  type_name : String,
  value : String,
) -> Result[String, String] {
  let parsed : UInt64 = @string.from_str(value) catch {
    _ => return Err("ROS " + type_name + " constants must be valid integers")
  }
  let maximum = match type_name {
    "byte" | "char" | "uint8" => 255UL
    "uint16" => 65535UL
    "uint32" => 4294967295UL
    "uint64" => 18446744073709551615UL
    _ => 0UL
  }
  if parsed > maximum {
    return Err("ROS " + type_name + " constant is out of range")
  }
  let literal = parsed.to_string()
  if type_name == "uint64" {
    Ok(literal + "UL")
  } else {
    Ok(literal)
  }
}

///|
fn rosidl_float_literal(value : String) -> Bool {
  let bytes = @utf8.encode(value)
  if bytes.length() == 0 {
    return false
  }
  let mut index = 0
  if bytes[index] == b'-' || bytes[index] == b'+' {
    index += 1
  }
  let (after_integer, integer_digits) = rosidl_float_digits(bytes, index)
  if integer_digits < 0 {
    return false
  }
  index = after_integer
  let mut mantissa_digits = integer_digits
  if index < bytes.length() && bytes[index] == b'.' {
    index += 1
    let (after_fraction, fraction_digits) = rosidl_float_digits(bytes, index)
    if fraction_digits < 0 {
      return false
    }
    index = after_fraction
    mantissa_digits += fraction_digits
  }
  if mantissa_digits == 0 {
    return false
  }
  if index < bytes.length() && (bytes[index] == b'e' || bytes[index] == b'E') {
    index += 1
    if index < bytes.length() && (bytes[index] == b'+' || bytes[index] == b'-') {
      index += 1
    }
    let (after_exponent, exponent_digits) = rosidl_float_digits(bytes, index)
    if exponent_digits <= 0 {
      return false
    }
    index = after_exponent
  }
  index == bytes.length()
}

///|
fn rosidl_float_digits(bytes : Bytes, start : Int) -> (Int, Int) {
  let mut index = start
  let mut digits = 0
  while index < bytes.length() {
    let byte = bytes[index]
    if byte >= 48 && byte <= 57 {
      digits += 1
      index += 1
    } else if byte == b'_' {
      if digits == 0 ||
        index + 1 >= bytes.length() ||
        bytes[index + 1] < 48 ||
        bytes[index + 1] > 57 {
        return (index, -1)
      }
      index += 1
    } else {
      break
    }
  }
  (index, digits)
}

///|
fn rosidl_normalize_float_literal(value : String) -> String {
  let bytes = @utf8.encode(value)
  let mut exponent_index = bytes.length()
  for index in 0..<bytes.length() {
    if bytes[index] == b'e' || bytes[index] == b'E' {
      exponent_index = index
      break
    }
  }
  let mantissa_start = if bytes[0] == b'+' || bytes[0] == b'-' { 1 } else { 0 }
  let mut has_dot = false
  for index in mantissa_start..<exponent_index {
    if bytes[index] == b'.' {
      has_dot = true
    }
  }
  let mut result = ""
  for index in 0..<bytes.length() {
    if (index == 0 && bytes[index] == b'+') || bytes[index] == b'_' {
      continue
    }
    if index == exponent_index && exponent_index < bytes.length() {
      if !has_dot {
        result += ".0"
      } else if bytes[index - 1] == b'.' {
        result += "0"
      }
      result += "e"
    } else if index == mantissa_start && bytes[index] == b'.' {
      result += "0."
    } else if bytes[index] == b'E' {
      result += "e"
    } else {
      result += @utf8.decode(Bytes::from_array([bytes[index]])) catch {
        _ => ""
      }
    }
  }
  if exponent_index == bytes.length() {
    if bytes[bytes.length() - 1] == b'.' {
      result += "0"
    } else if !has_dot {
      result += ".0"
    }
  }
  result
}
