///|
/// RTPS parameter identifiers used by SPDP and SEDP.
pub const PID_SENTINEL : UInt16 = 0x0001

///|
pub const PID_PARTICIPANT_LEASE_DURATION : UInt16 = 0x0002

///|
pub const PID_DOMAIN_ID : UInt16 = 0x000F

///|
pub const PID_TOPIC_NAME : UInt16 = 0x0005

///|
pub const PID_TYPE_NAME : UInt16 = 0x0007

///|
pub const PID_UNICAST_LOCATOR : UInt16 = 0x002F

///|
pub const PID_MULTICAST_LOCATOR : UInt16 = 0x0030

///|
pub const PID_RELIABILITY : UInt16 = 0x001A

///|
pub const PID_DURABILITY : UInt16 = 0x001D

///|
pub const PID_DEADLINE : UInt16 = 0x0023

///|
pub const PID_LATENCY_BUDGET : UInt16 = 0x0027

///|
pub const PID_LIVELINESS : UInt16 = 0x001B

///|
pub const PID_LIFESPAN : UInt16 = 0x002B

///|
/// Entity user data, such as the ROS 2 type hash advertised in SEDP.
pub const PID_USER_DATA : UInt16 = 0x002C

///|
pub const PID_DESTINATION_ORDER : UInt16 = 0x0025

///|
pub const PID_HISTORY : UInt16 = 0x0040

///|
pub const PID_RESOURCE_LIMITS : UInt16 = 0x0041

///|
pub const PID_EXPECTS_INLINE_QOS : UInt16 = 0x0043

///|
pub const PID_OWNERSHIP : UInt16 = 0x001F

///|
pub const PID_OWNERSHIP_STRENGTH : UInt16 = 0x0006

///|
pub const PID_PARTICIPANT_GUID : UInt16 = 0x0050

///|
pub const PID_ENDPOINT_GUID : UInt16 = 0x005A

///|
pub const PID_DATA_REPRESENTATION : UInt16 = 0x0073

///|
/// DDS-RPC service instance name used by enhanced service discovery.
pub const PID_SERVICE_INSTANCE_NAME : UInt16 = 0x0080

///|
/// GUID of the related request or response endpoint in DDS-RPC discovery.
pub const PID_RELATED_ENTITY_GUID : UInt16 = 0x0081

///|
/// Alternate topic names used by enhanced DDS-RPC service discovery.
pub const PID_TOPIC_ALIASES : UInt16 = 0x0082

///|
/// Related request identity carried by DDS-RPC reply samples.
pub const PID_RELATED_SAMPLE_IDENTITY : UInt16 = 0x0083

///|
pub const PID_TYPE_MAX_SIZE_SERIALIZED : UInt16 = 0x0060

///|
/// Endpoint instance key hash, normally derived from the endpoint GUID.
pub const PID_KEY_HASH : UInt16 = 0x0070

///|
/// Entity lifecycle state carried in an RTPS DATA inline-QoS list.
pub const PID_STATUS_INFO : UInt16 = 0x0071

///|
pub const PID_PROTOCOL_VERSION : UInt16 = 0x0015

///|
pub const PID_VENDOR_ID : UInt16 = 0x0016

///|
pub const PID_METATRAFFIC_UNICAST_LOCATOR : UInt16 = 0x0032

///|
pub const PID_METATRAFFIC_MULTICAST_LOCATOR : UInt16 = 0x0033

///|
pub const PID_DEFAULT_UNICAST_LOCATOR : UInt16 = 0x0031

///|
pub const PID_DEFAULT_MULTICAST_LOCATOR : UInt16 = 0x0048

///|
pub const PID_BUILTIN_ENDPOINT_SET : UInt16 = 0x0058

///|
/// One RTPS parameter value; known scalar fields are normalized to little-endian.
pub struct Parameter {
  id : UInt16
  value : Bytes
} derive(Eq, Debug)

///|
pub extend Parameter with Eq::{not_equal, equal}

///|
pub extend Parameter with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub fn Parameter::new(id : UInt16, value : Bytes) -> Parameter {
  { id, value, }
}

///|
pub fn Parameter::id(self : Parameter) -> UInt16 {
  self.id
}

///|
pub fn Parameter::value(self : Parameter) -> Bytes {
  self.value
}

///|
/// A CDR parameter list used by RTPS builtin discovery data.
pub struct ParameterList {
  values : Array[Parameter]
}

///|
pub fn ParameterList::new() -> ParameterList {
  { values: [], }
}

///|
/// Append one parameter before the final sentinel.
pub fn ParameterList::add(self : ParameterList, parameter : Parameter) -> Unit {
  self.values.push(parameter)
}

///|
/// Return the parameters in insertion order.
pub fn ParameterList::values(self : ParameterList) -> Array[Parameter] {
  self.values
}

///|
fn append_u16_le(bytes : Array[Byte], value : UInt16) -> Unit {
  let int_value = value.to_int()
  bytes.push((int_value & 0xFF).to_byte())
  bytes.push(((int_value >> 8) & 0xFF).to_byte())
}

///|
fn read_u16_with_endianness(
  input : Bytes,
  offset : Int,
  little_endian : Bool,
) -> UInt16 {
  let value = if little_endian {
    input[offset].to_int() | (input[offset + 1].to_int() << 8)
  } else {
    (input[offset].to_int() << 8) | input[offset + 1].to_int()
  }
  value.to_uint16()
}

///|
fn read_u32_with_endianness(
  input : Bytes,
  offset : Int,
  little_endian : Bool,
) -> UInt {
  if little_endian {
    input[offset].to_int().reinterpret_as_uint() |
    (input[offset + 1].to_int().reinterpret_as_uint() << 8) |
    (input[offset + 2].to_int().reinterpret_as_uint() << 16) |
    (input[offset + 3].to_int().reinterpret_as_uint() << 24)
  } else {
    (input[offset].to_int().reinterpret_as_uint() << 24) |
    (input[offset + 1].to_int().reinterpret_as_uint() << 16) |
    (input[offset + 2].to_int().reinterpret_as_uint() << 8) |
    input[offset + 3].to_int().reinterpret_as_uint()
  }
}

///|
fn parameter_normalize_u32_words(
  value : Bytes,
  offset : Int,
  word_count : Int,
) -> Bytes {
  let byte_count = word_count * 4
  if word_count == 0 || offset < 0 || value.length() < offset + byte_count {
    return value
  }
  let normalized : Array[Byte] = []
  for index in 0..<value.length() {
    if index >= offset && index < offset + byte_count {
      let word_offset = offset + (index - offset) / 4 * 4
      normalized.push(value[word_offset + 3 - (index - offset) % 4])
    } else {
      normalized.push(value[index])
    }
  }
  Bytes::from_array(normalized)
}

///|
fn parameter_normalize_data_representation(value : Bytes) -> Bytes {
  if value.length() < 4 {
    return value
  }
  let count = read_u32_with_endianness(value, 0, false).reinterpret_as_int()
  let normalized = parameter_normalize_u32_words(value, 0, 1)
  if count < 0 || count > (value.length() - 4) / 2 {
    return normalized
  }
  let result : Array[Byte] = []
  for index in 0..<normalized.length() {
    if index >= 4 && index < 4 + count * 2 {
      result.push(normalized[4 + (index - 4) / 2 * 2 + 1 - (index - 4) % 2])
    } else {
      result.push(normalized[index])
    }
  }
  Bytes::from_array(result)
}

///|

///|
/// Normalize known CDR fields for parsers that use little-endian values.
fn parameter_normalize_big_endian_value(id : UInt16, value : Bytes) -> Bytes {
  if id == PID_DATA_REPRESENTATION {
    return parameter_normalize_data_representation(value)
  }
  if id == PID_RELATED_SAMPLE_IDENTITY {
    return parameter_normalize_u32_words(value, 16, 2)
  }
  let word_count = match id {
    PID_PARTICIPANT_LEASE_DURATION
    | PID_DEADLINE
    | PID_LATENCY_BUDGET
    | PID_LIFESPAN => 2
    PID_UNICAST_LOCATOR
    | PID_MULTICAST_LOCATOR
    | PID_METATRAFFIC_UNICAST_LOCATOR
    | PID_METATRAFFIC_MULTICAST_LOCATOR
    | PID_DEFAULT_UNICAST_LOCATOR
    | PID_DEFAULT_MULTICAST_LOCATOR => 2
    PID_RELIABILITY | PID_LIVELINESS | PID_RESOURCE_LIMITS => 3
    PID_HISTORY => 2
    PID_TOPIC_NAME
    | PID_TYPE_NAME
    | PID_USER_DATA
    | PID_SERVICE_INSTANCE_NAME => 1
    PID_DOMAIN_ID
    | PID_BUILTIN_ENDPOINT_SET
    | PID_TYPE_MAX_SIZE_SERIALIZED
    | PID_STATUS_INFO
    | PID_DURABILITY
    | PID_DESTINATION_ORDER
    | PID_OWNERSHIP
    | PID_OWNERSHIP_STRENGTH => 1
    _ => 0
  }
  parameter_normalize_u32_words(value, 0, word_count)
}

///|
fn append_parameter(bytes : Array[Byte], parameter : Parameter) -> Unit {
  let value = parameter.value
  let padded_length = (value.length() + 3) / 4 * 4
  append_u16_le(bytes, parameter.id)
  append_u16_le(bytes, padded_length.to_uint16())
  for i in 0..<value.length() {
    bytes.push(value[i])
  }
  if padded_length != value.length() {
    for _ in 0..<(padded_length - value.length()) {
      bytes.push(0)
    }
  }
}

///|
/// Serialize the parameter list body, including a PID_SENTINEL.
pub fn ParameterList::to_bytes(self : ParameterList) -> Bytes {
  let bytes : Array[Byte] = []
  for parameter in self.values {
    append_parameter(bytes, parameter)
  }
  append_u16_le(bytes, PID_SENTINEL)
  append_u16_le(bytes, (0 : UInt16))
  Bytes::from_array(bytes)
}

///|
/// Serialize the parameter list with a CDR little-endian encapsulation header.
pub fn ParameterList::to_cdr_bytes(self : ParameterList) -> Bytes {
  let body = self.to_bytes()
  // RTPS ParameterList CDR uses the PL_CDR_LE encapsulation identifier
  // (0x0003), distinct from the regular CDR_LE identifier (0x0001).
  let bytes : Array[Byte] = [0, 3, 0, 0]
  for i in 0..<body.length() {
    bytes.push(body[i])
  }
  Bytes::from_array(bytes)
}

///|
/// Parse a parameter list body and return the consumed byte count.
pub fn ParameterList::from_bytes(
  input : Bytes,
) -> Result[(ParameterList, Int), String] {
  ParameterList::from_bytes_with_endianness(input, true)
}

///|
/// Parse a parameter list body using the enclosing DATA submessage byte order.
fn ParameterList::from_bytes_with_endianness(
  input : Bytes,
  little_endian : Bool,
) -> Result[(ParameterList, Int), String] {
  let result = ParameterList::new()
  let mut offset = 0
  while offset + 4 <= input.length() {
    let id = read_u16_with_endianness(input, offset, little_endian)
    let length = read_u16_with_endianness(input, offset + 2, little_endian).to_int()
    offset += 4
    if id == PID_SENTINEL {
      if length != 0 {
        return Err("RTPS PID_SENTINEL must have zero length")
      }
      return Ok((result, offset))
    }
    if length % 4 != 0 {
      return Err("RTPS parameter length must be a multiple of four")
    }
    if offset + length > input.length() {
      return Err("truncated RTPS parameter value")
    }
    let value = bytes_from(input, offset, length)
    let value = if little_endian {
      value
    } else {
      parameter_normalize_big_endian_value(id, value)
    }
    result.add(Parameter::new(id, value))
    offset += length
  }
  Err("RTPS parameter list has no PID_SENTINEL")
}

///|
/// Parse a PL_CDR_BE or PL_CDR_LE parameter list into normalized values.
pub fn ParameterList::from_cdr_bytes(
  input : Bytes,
) -> Result[ParameterList, String] {
  if input.length() < 4 {
    return Err("a CDR parameter list must have a 4-byte encapsulation header")
  }
  if input[0] != 0 || (input[1] != 2 && input[1] != 3) {
    return Err("only RTPS PL_CDR_BE and PL_CDR_LE encodings are supported")
  }
  let little_endian = input[1] == 3
  let body = bytes_from(input, 4, input.length() - 4)
  match ParameterList::from_bytes_with_endianness(body, little_endian) {
    Ok((parameters, _)) => Ok(parameters)
    Err(message) => Err(message)
  }
}

///|
/// Parse a ParameterList carried directly in an RTPS DATA payload.
///
/// RTPS implementations use both PL_CDR encapsulation forms and the
/// DATA form whose payload starts at the first parameter identifier. Keep
/// `from_cdr_bytes` strict for standalone CDR values, while accepting both
/// wire forms at the DATA boundary.
pub fn ParameterList::from_data_bytes(
  input : Bytes,
) -> Result[ParameterList, String] {
  if input.length() >= 4 && input[0] == 0 && (input[1] == 2 || input[1] == 3) {
    return ParameterList::from_cdr_bytes(input)
  }
  match ParameterList::from_bytes(input) {
    Ok((parameters, _)) => Ok(parameters)
    Err(message) => Err(message)
  }
}
