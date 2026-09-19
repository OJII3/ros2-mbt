///|
/// The kind of endpoint announced by an SEDP sample.
pub(all) enum SedpEndpointKind {
  Publication
  Subscription
} derive(Eq, Debug)

///|
/// Entity ID suffix for the SEDP publications writer.
pub const ENTITYID_SEDP_PUBLICATIONS_WRITER : Byte = 0xC2

///|
/// Entity ID suffix for the SEDP publications reader.
pub const ENTITYID_SEDP_PUBLICATIONS_READER : Byte = 0xC7

///|
/// Entity ID suffix for the SEDP subscriptions writer.
pub const ENTITYID_SEDP_SUBSCRIPTIONS_WRITER : Byte = 0xC2

///|
/// Entity ID suffix for the SEDP subscriptions reader.
pub const ENTITYID_SEDP_SUBSCRIPTIONS_READER : Byte = 0xC7

///|
/// A common SEDP publication/subscription endpoint sample.
pub struct SedpEndpointData {
  kind : SedpEndpointKind
  endpoint_guid : Guid
  participant_guid : Guid
  topic_name : String
  type_name : String
  unicast_locators : Array[Locator]
  multicast_locators : Array[Locator]
  extra_parameters : Array[Parameter]
} derive(Eq, Debug)

///|
/// Create an SEDP endpoint sample with the three required identity fields.
pub fn SedpEndpointData::new(
  kind : SedpEndpointKind,
  endpoint_guid : Guid,
  topic_name : String,
  type_name : String,
) -> Result[SedpEndpointData, String] {
  if topic_name.length() == 0 || type_name.length() == 0 {
    return Err("SEDP topic and type names must not be empty")
  }
  Ok({
    kind,
    endpoint_guid,
    participant_guid: Guid::new(
      endpoint_guid.prefix(),
      EntityId::new(b"\x00\x00\x00", 0x01).unwrap(),
    ),
    topic_name,
    type_name,
    unicast_locators: [],
    multicast_locators: [],
    extra_parameters: [],
  })
}

///|
/// Create an SEDP endpoint sample with an explicit participant GUID.
pub fn SedpEndpointData::with_participant_guid(
  self : SedpEndpointData,
  participant_guid : Guid,
) -> SedpEndpointData {
  { ..self, participant_guid, }
}

///|
pub fn SedpEndpointData::kind(self : SedpEndpointData) -> SedpEndpointKind {
  self.kind
}

///|
pub fn SedpEndpointData::endpoint_guid(self : SedpEndpointData) -> Guid {
  self.endpoint_guid
}

///|
pub fn SedpEndpointData::participant_guid(self : SedpEndpointData) -> Guid {
  self.participant_guid
}

///|
pub fn SedpEndpointData::topic_name(self : SedpEndpointData) -> String {
  self.topic_name
}

///|
pub fn SedpEndpointData::type_name(self : SedpEndpointData) -> String {
  self.type_name
}

///|
pub fn SedpEndpointData::add_unicast_locator(
  self : SedpEndpointData,
  locator : Locator,
) -> Unit {
  self.unicast_locators.push(locator)
}

///|
pub fn SedpEndpointData::add_multicast_locator(
  self : SedpEndpointData,
  locator : Locator,
) -> Unit {
  self.multicast_locators.push(locator)
}

///|
/// Preserve an arbitrary QoS or vendor-specific parameter.
pub fn SedpEndpointData::add_parameter(
  self : SedpEndpointData,
  parameter : Parameter,
) -> Unit {
  self.extra_parameters.push(parameter)
}

///|
fn sedp_u32_le(value : UInt) -> Bytes {
  Bytes::from_array([
    value.to_byte(),
    (value >> 8).to_byte(),
    (value >> 16).to_byte(),
    (value >> 24).to_byte(),
  ])
}

///|
fn sedp_string(value : String) -> Result[Bytes, String] {
  let encoded = @utf8.encode(value)
  let length = encoded.length() + 1
  if length > 0xFFFF - 4 {
    return Err("an SEDP string parameter is too long")
  }
  let bytes : Array[Byte] = []
  let length_bytes = sedp_u32_le(length.reinterpret_as_uint())
  for i in 0..<4 {
    bytes.push(length_bytes[i])
  }
  for byte in encoded {
    bytes.push(byte)
  }
  bytes.push(0)
  Ok(Bytes::from_array(bytes))
}

///|
fn sedp_required(
  parameters : ParameterList,
  id : UInt16,
  label : String,
) -> Result[Bytes, String] {
  for parameter in parameters.values() {
    if parameter.id() == id {
      return Ok(parameter.value())
    }
  }
  Err("SEDP is missing " + label)
}

///|
fn sedp_read_string(value : Bytes, label : String) -> Result[String, String] {
  if value.length() < 5 {
    return Err("SEDP " + label + " is truncated")
  }
  let length = match value[0:4] {
    [u32le(result)] => result.reinterpret_as_int()
    _ => return Err("invalid SEDP " + label + " length")
  }
  if length <= 0 || 4 + length > value.length() {
    return Err("invalid SEDP " + label + " length")
  }
  if value[4 + length - 1] != 0 {
    return Err("SEDP " + label + " is not NUL terminated")
  }
  Ok(@utf8.decode(value[4:4 + length - 1])) catch {
    _ => Err("invalid UTF-8 in SEDP " + label)
  }
}

///|
fn sedp_is_identity_parameter(id : UInt16) -> Bool {
  id == PID_ENDPOINT_GUID ||
  id == PID_PARTICIPANT_GUID ||
  id == PID_TOPIC_NAME ||
  id == PID_TYPE_NAME ||
  id == PID_UNICAST_LOCATOR ||
  id == PID_MULTICAST_LOCATOR
}

///|
/// Serialize this endpoint sample as a discovery parameter list.
pub fn SedpEndpointData::to_parameter_list(
  self : SedpEndpointData,
) -> Result[ParameterList, String] {
  let parameters = ParameterList::new()
  parameters.add(
    Parameter::new(PID_ENDPOINT_GUID, self.endpoint_guid.to_bytes()),
  )
  parameters.add(
    Parameter::new(PID_PARTICIPANT_GUID, self.participant_guid.to_bytes()),
  )
  parameters.add(
    Parameter::new(
      PID_TOPIC_NAME,
      match sedp_string(self.topic_name) {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    ),
  )
  parameters.add(
    Parameter::new(
      PID_TYPE_NAME,
      match sedp_string(self.type_name) {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    ),
  )
  for locator in self.unicast_locators {
    parameters.add(Parameter::new(PID_UNICAST_LOCATOR, locator.to_bytes()))
  }
  for locator in self.multicast_locators {
    parameters.add(Parameter::new(PID_MULTICAST_LOCATOR, locator.to_bytes()))
  }
  for parameter in self.extra_parameters {
    parameters.add(parameter)
  }
  Ok(parameters)
}

///|
/// Serialize this endpoint sample as a CDR little-endian payload.
pub fn SedpEndpointData::to_cdr_bytes(
  self : SedpEndpointData,
) -> Result[Bytes, String] {
  let parameters = match self.to_parameter_list() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(parameters.to_cdr_bytes())
}

///|
/// Build a DATA submessage carrying this SEDP endpoint sample.
pub fn SedpEndpointData::to_data_submessage(
  self : SedpEndpointData,
  reader_id : EntityId,
  writer_id : EntityId,
  writer_sequence_number : Int64,
) -> Result[DataSubmessage, String] {
  let payload = match self.to_cdr_bytes() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(DataSubmessage::new(reader_id, writer_id, writer_sequence_number, payload))
}

///|
/// Parse an SEDP endpoint sample from a DATA submessage.
pub fn SedpEndpointData::from_data_submessage(
  kind : SedpEndpointKind,
  data : DataSubmessage,
) -> Result[SedpEndpointData, String] {
  SedpEndpointData::from_cdr_bytes(kind, data.serialized_payload())
}

///|
/// Build an RTPS message containing this SEDP endpoint announcement.
pub fn SedpEndpointData::to_message(
  self : SedpEndpointData,
  vendor_id : VendorId,
  reader_id : EntityId,
  writer_id : EntityId,
  writer_sequence_number : Int64,
) -> Result[Message, String] {
  let data = match
    self.to_data_submessage(reader_id, writer_id, writer_sequence_number) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let message = Message::new(
    Header::new(self.participant_guid.prefix(), vendor_id),
  )
  message.add(data.to_submessage())
  Ok(message)
}

///|
/// Parse an SEDP endpoint sample from a parameter list.
pub fn SedpEndpointData::from_parameter_list(
  kind : SedpEndpointKind,
  parameters : ParameterList,
) -> Result[SedpEndpointData, String] {
  let endpoint_guid = match
    Guid::from_bytes(
      match sedp_required(parameters, PID_ENDPOINT_GUID, "PID_ENDPOINT_GUID") {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let topic_name = match
    sedp_read_string(
      match sedp_required(parameters, PID_TOPIC_NAME, "PID_TOPIC_NAME") {
        Ok(value) => value
        Err(message) => return Err(message)
      },
      "topic name",
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let type_name = match
    sedp_read_string(
      match sedp_required(parameters, PID_TYPE_NAME, "PID_TYPE_NAME") {
        Ok(value) => value
        Err(message) => return Err(message)
      },
      "type name",
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let participant_guid = match
    sedp_required(parameters, PID_PARTICIPANT_GUID, "PID_PARTICIPANT_GUID") {
    Ok(value) =>
      match Guid::from_bytes(value) {
        Ok(guid) => guid
        Err(message) => return Err(message)
      }
    Err(_) =>
      Guid::new(
        endpoint_guid.prefix(),
        EntityId::new(b"\x00\x00\x00", 0x01).unwrap(),
      )
  }
  let result = match
    SedpEndpointData::new(kind, endpoint_guid, topic_name, type_name) {
    Ok(value) => value.with_participant_guid(participant_guid)
    Err(message) => return Err(message)
  }
  for parameter in parameters.values() {
    match parameter.id() {
      PID_UNICAST_LOCATOR =>
        result.unicast_locators.push(
          match Locator::from_bytes(parameter.value()) {
            Ok(value) => value
            Err(message) => return Err(message)
          },
        )
      PID_MULTICAST_LOCATOR =>
        result.multicast_locators.push(
          match Locator::from_bytes(parameter.value()) {
            Ok(value) => value
            Err(message) => return Err(message)
          },
        )
      _ if !sedp_is_identity_parameter(parameter.id()) =>
        result.extra_parameters.push(parameter)
      _ => ()
    }
  }
  Ok(result)
}

///|
/// Parse a CDR little-endian SEDP endpoint sample.
pub fn SedpEndpointData::from_cdr_bytes(
  kind : SedpEndpointKind,
  input : Bytes,
) -> Result[SedpEndpointData, String] {
  let parameters = match ParameterList::from_cdr_bytes(input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  SedpEndpointData::from_parameter_list(kind, parameters)
}
