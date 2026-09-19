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
/// Return the builtin SEDP reader used by the remote participant.
pub fn SedpEndpointKind::builtin_reader_id(self : SedpEndpointKind) -> EntityId {
  match self {
    SedpEndpointKind::Publication =>
      EntityId::new(b"\x00\x00\x03", ENTITYID_SEDP_PUBLICATIONS_READER).unwrap()
    SedpEndpointKind::Subscription =>
      EntityId::new(b"\x00\x00\x04", ENTITYID_SEDP_SUBSCRIPTIONS_READER).unwrap()
  }
}

///|
/// Return the builtin SEDP writer used by the local participant.
pub fn SedpEndpointKind::builtin_writer_id(self : SedpEndpointKind) -> EntityId {
  match self {
    SedpEndpointKind::Publication =>
      EntityId::new(b"\x00\x00\x03", ENTITYID_SEDP_PUBLICATIONS_WRITER).unwrap()
    SedpEndpointKind::Subscription =>
      EntityId::new(b"\x00\x00\x04", ENTITYID_SEDP_SUBSCRIPTIONS_WRITER).unwrap()
  }
}

///|
/// Resolve the SEDP kind from a predefined builtin writer entity ID.
///
/// The publications and subscriptions writers use entity keys 0x000003 and
/// 0x000004 respectively. The entity kind is the ordinary writer kind 0xC2.
pub fn SedpEndpointKind::from_builtin_writer_id(
  writer_id : EntityId,
) -> Result[SedpEndpointKind, String] {
  if writer_id.kind() != ENTITYID_SEDP_PUBLICATIONS_WRITER {
    return Err("the entity is not an SEDP writer")
  }
  if writer_id.key() == b"\x00\x00\x03" {
    return Ok(SedpEndpointKind::Publication)
  }
  if writer_id.key() == b"\x00\x00\x04" {
    return Ok(SedpEndpointKind::Subscription)
  }
  Err("the entity is not a predefined SEDP writer")
}

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
/// The QoS policies needed for basic DDS endpoint compatibility.
pub struct SedpQos {
  reliability : UInt
  durability : UInt
  history : UInt
  depth : Int
  data_representation : Array[UInt16]
} derive(Eq, Debug)

///|
pub fn SedpQos::new(
  reliability : UInt,
  durability : UInt,
  history : UInt,
  depth : Int,
) -> SedpQos {
  {
    reliability,
    durability,
    history,
    depth,
    data_representation: [DATA_REPRESENTATION_XCDR1],
  }
}

///|
/// Create a QoS value with an explicit offered/requested data representation set.
pub fn SedpQos::with_data_representation(
  self : SedpQos,
  representations : Array[UInt16],
) -> SedpQos {
  { ..self, data_representation: representations, }
}

///|
pub fn SedpQos::reliability(self : SedpQos) -> UInt {
  self.reliability
}

///|
pub fn SedpQos::durability(self : SedpQos) -> UInt {
  self.durability
}

///|
pub fn SedpQos::history(self : SedpQos) -> UInt {
  self.history
}

///|
pub fn SedpQos::depth(self : SedpQos) -> Int {
  self.depth
}

///|
/// Return the CDR data representations supported by this endpoint.
pub fn SedpQos::data_representation(self : SedpQos) -> Array[UInt16] {
  self.data_representation
}

///|
/// DDS defaults used when an SEDP endpoint omits a recognized QoS policy.
pub fn SedpQos::default() -> SedpQos {
  SedpQos::new(
    RELIABILITY_BEST_EFFORT,
    DURABILITY_VOLATILE,
    HISTORY_KEEP_LAST,
    1,
  )
}

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
      EntityId::new(b"\x00\x01\x00", 0xC1).unwrap(),
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
pub fn SedpEndpointData::unicast_locators(
  self : SedpEndpointData,
) -> Array[Locator] {
  self.unicast_locators
}

///|
pub fn SedpEndpointData::multicast_locators(
  self : SedpEndpointData,
) -> Array[Locator] {
  self.multicast_locators
}

///|
pub fn SedpEndpointData::extra_parameters(
  self : SedpEndpointData,
) -> Array[Parameter] {
  self.extra_parameters
}

///|
fn sedp_qos_u32(value : Bytes, label : String) -> Result[UInt, String] {
  if value.length() < 4 {
    return Err("SEDP " + label + " parameter is truncated")
  }
  match value[0:4] {
    [u32le(result)] => Ok(result)
    _ => Err("invalid SEDP " + label + " parameter")
  }
}

///|
fn sedp_qos_i32(value : Bytes, label : String) -> Result[Int, String] {
  match sedp_qos_u32(value, label) {
    Ok(result) => Ok(result.reinterpret_as_int())
    Err(message) => Err(message)
  }
}

///|
fn sedp_qos_data_representation(value : Bytes) -> Result[Array[UInt16], String] {
  if value.length() < 4 {
    return Err("SEDP data representation parameter is truncated")
  }
  let length = match value[0:4] {
    [u32le(result)] => result.reinterpret_as_int()
    _ => return Err("invalid SEDP data representation parameter")
  }
  if length < 0 || 4 + length * 2 > value.length() {
    return Err("invalid SEDP data representation sequence length")
  }
  let representations : Array[UInt16] = []
  for index in 0..<length {
    let offset = 4 + index * 2
    let representation = (value[offset].to_int() |
    (value[offset + 1].to_int() << 8)).to_uint16()
    representations.push(representation)
  }
  if representations.length() == 0 {
    return Err("SEDP data representation sequence must not be empty")
  }
  Ok(representations)
}

///|
/// Read the reliability, durability, and history policies from SEDP.
pub fn SedpEndpointData::qos(
  self : SedpEndpointData,
) -> Result[SedpQos, String] {
  let defaults = SedpQos::default()
  let mut reliability = defaults.reliability
  let mut durability = defaults.durability
  let mut history = defaults.history
  let mut depth = defaults.depth
  let mut data_representation = defaults.data_representation
  for parameter in self.extra_parameters {
    match parameter.id() {
      PID_RELIABILITY =>
        reliability = match sedp_qos_u32(parameter.value(), "reliability") {
          Ok(value) => value
          Err(message) => return Err(message)
        }
      PID_DURABILITY =>
        durability = match sedp_qos_u32(parameter.value(), "durability") {
          Ok(value) => value
          Err(message) => return Err(message)
        }
      PID_HISTORY => {
        if parameter.value().length() < 8 {
          return Err("SEDP history parameter is truncated")
        }
        history = match sedp_qos_u32(parameter.value(), "history") {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        let value = parameter.value()
        let depth_bytes = Bytes::from_array([
          value[4],
          value[5],
          value[6],
          value[7],
        ])
        depth = match sedp_qos_i32(depth_bytes, "history depth") {
          Ok(value) => value
          Err(message) => return Err(message)
        }
      }
      PID_DATA_REPRESENTATION =>
        data_representation = match
          sedp_qos_data_representation(parameter.value()) {
          Ok(value) => value
          Err(message) => return Err(message)
        }
      _ => ()
    }
  }
  Ok(
    SedpQos::new(reliability, durability, history, depth).with_data_representation(
      data_representation,
    ),
  )
}

///|
fn sedp_data_representation_intersects(
  offered : Array[UInt16],
  requested : Array[UInt16],
) -> Bool {
  for offered_value in offered {
    for requested_value in requested {
      if offered_value == requested_value {
        return true
      }
    }
  }
  false
}

///|
/// Check the basic offered/requested QoS compatibility of a writer and reader.
pub fn SedpEndpointData::qos_compatible_with(
  self : SedpEndpointData,
  reader : SedpEndpointData,
) -> Result[Bool, String] {
  if self.kind != SedpEndpointKind::Publication {
    return Err("the offered endpoint must be an SEDP publication")
  }
  if reader.kind != SedpEndpointKind::Subscription {
    return Err("the requested endpoint must be an SEDP subscription")
  }
  let offered = match self.qos() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let requested = match reader.qos() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(
    offered.reliability >= requested.reliability &&
    offered.durability >= requested.durability &&
    sedp_data_representation_intersects(
      offered.data_representation,
      requested.data_representation,
    ),
  )
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
  id == PID_KEY_HASH ||
  id == PID_PROTOCOL_VERSION ||
  id == PID_VENDOR_ID ||
  id == PID_TOPIC_NAME ||
  id == PID_TYPE_NAME ||
  id == PID_UNICAST_LOCATOR ||
  id == PID_MULTICAST_LOCATOR
}

///|
fn sedp_has_parameter(parameters : Array[Parameter], id : UInt16) -> Bool {
  for parameter in parameters {
    if parameter.id() == id {
      return true
    }
  }
  false
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
  parameters.add(Parameter::new(PID_KEY_HASH, self.endpoint_guid.to_bytes()))
  for locator in self.unicast_locators {
    parameters.add(Parameter::new(PID_UNICAST_LOCATOR, locator.to_bytes()))
  }
  for locator in self.multicast_locators {
    parameters.add(Parameter::new(PID_MULTICAST_LOCATOR, locator.to_bytes()))
  }
  if self.kind == SedpEndpointKind::Publication &&
    !sedp_has_parameter(self.extra_parameters, PID_TYPE_MAX_SIZE_SERIALIZED) {
    parameters.add(qos_type_max_size_serialized(0))
  }
  if self.kind == SedpEndpointKind::Subscription &&
    !sedp_has_parameter(self.extra_parameters, PID_EXPECTS_INLINE_QOS) {
    parameters.add(qos_expects_inline_qos(false))
  }
  for parameter in self.extra_parameters {
    parameters.add(parameter)
  }
  Ok(parameters)
}

///|
/// Serialize an endpoint with the protocol and vendor parameters emitted by
/// the local RTPS implementation.
pub fn SedpEndpointData::to_parameter_list_with_vendor(
  self : SedpEndpointData,
  vendor_id : VendorId,
) -> Result[ParameterList, String] {
  let parameters = match self.to_parameter_list() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  parameters.add(
    Parameter::new(
      PID_PROTOCOL_VERSION,
      Bytes::from_array([PROTOCOL_VERSION_MAJOR, PROTOCOL_VERSION_MINOR, 0, 0]),
    ),
  )
  parameters.add(
    Parameter::new(
      PID_VENDOR_ID,
      Bytes::from_array([vendor_id.major, vendor_id.minor, 0, 0]),
    ),
  )
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
/// Serialize an endpoint payload including its protocol and vendor identity.
pub fn SedpEndpointData::to_cdr_bytes_with_vendor(
  self : SedpEndpointData,
  vendor_id : VendorId,
) -> Result[Bytes, String] {
  let parameters = match self.to_parameter_list_with_vendor(vendor_id) {
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
/// Build an SEDP DATA submessage with protocol and vendor identity parameters.
pub fn SedpEndpointData::to_data_submessage_with_vendor(
  self : SedpEndpointData,
  vendor_id : VendorId,
  reader_id : EntityId,
  writer_id : EntityId,
  writer_sequence_number : Int64,
) -> Result[DataSubmessage, String] {
  let payload = match self.to_cdr_bytes_with_vendor(vendor_id) {
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
    self.to_data_submessage_with_vendor(
      vendor_id, reader_id, writer_id, writer_sequence_number,
    ) {
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
        EntityId::new(b"\x00\x01\x00", 0xC1).unwrap(),
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
