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
/// Related request identity carried by DDS-RPC reply samples.
pub const PID_RELATED_SAMPLE_IDENTITY : UInt16 = 0x0083

///|
pub const PID_TYPE_MAX_SIZE_SERIALIZED : UInt16 = 0x0060

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
/// One RTPS parameter with an opaque, little-endian value.
pub struct Parameter {
  id : UInt16
  value : Bytes
} derive(Eq, Debug)

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
fn read_u16_le(input : Bytes, offset : Int) -> UInt16 {
  let value = input[offset].to_int() | (input[offset + 1].to_int() << 8)
  value.to_uint16()
}

///|
fn append_parameter(bytes : Array[Byte], parameter : Parameter) -> Unit {
  let value = parameter.value
  append_u16_le(bytes, parameter.id)
  append_u16_le(bytes, value.length().to_uint16())
  for i in 0..<value.length() {
    bytes.push(value[i])
  }
  let remainder = value.length() % 4
  if remainder != 0 {
    for _ in 0..<(4 - remainder) {
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
  let bytes : Array[Byte] = [0, 1, 0, 0]
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
  let result = ParameterList::new()
  let mut offset = 0
  while offset + 4 <= input.length() {
    let id = read_u16_le(input, offset)
    let length = read_u16_le(input, offset + 2).to_int()
    offset += 4
    if id == PID_SENTINEL {
      if length != 0 {
        return Err("RTPS PID_SENTINEL must have zero length")
      }
      return Ok((result, offset))
    }
    if offset + length > input.length() {
      return Err("truncated RTPS parameter value")
    }
    let value = bytes_from(input, offset, length)
    result.add(Parameter::new(id, value))
    offset += length
    let remainder = length % 4
    if remainder != 0 {
      let padding = 4 - remainder
      if offset + padding > input.length() {
        return Err("truncated RTPS parameter padding")
      }
      offset += padding
    }
  }
  Err("RTPS parameter list has no PID_SENTINEL")
}

///|
/// Parse a CDR little-endian parameter list.
pub fn ParameterList::from_cdr_bytes(
  input : Bytes,
) -> Result[ParameterList, String] {
  if input.length() < 4 {
    return Err("a CDR parameter list must have a 4-byte encapsulation header")
  }
  if input[0] != 0 || input[1] != 1 || input[2] != 0 || input[3] != 0 {
    return Err("only CDR little-endian parameter lists are supported")
  }
  let body = bytes_from(input, 4, input.length() - 4)
  match ParameterList::from_bytes(body) {
    Ok((parameters, _)) => Ok(parameters)
    Err(message) => Err(message)
  }
}
