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
/// DDS QoS policies needed for endpoint compatibility checks.
pub struct SedpQos {
  reliability : UInt
  durability : UInt
  history : UInt
  depth : Int
  data_representation : Array[UInt16]
  deadline_seconds : Int
  deadline_fraction : UInt
  liveliness : UInt
  liveliness_lease_seconds : Int
  liveliness_lease_fraction : UInt
} derive(Eq, Debug)

///|
const SEDP_QOS_DURATION_INFINITE_SECONDS : Int = 0x7FFFFFFF

///|
const SEDP_QOS_DURATION_INFINITE_FRACTION : UInt = 0xFFFFFFFFU

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
    deadline_seconds: SEDP_QOS_DURATION_INFINITE_SECONDS,
    deadline_fraction: SEDP_QOS_DURATION_INFINITE_FRACTION,
    liveliness: LIVELINESS_AUTOMATIC,
    liveliness_lease_seconds: SEDP_QOS_DURATION_INFINITE_SECONDS,
    liveliness_lease_fraction: SEDP_QOS_DURATION_INFINITE_FRACTION,
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
/// Set the offered/requested deadline in seconds and nanoseconds.
pub fn SedpQos::with_deadline(
  self : SedpQos,
  seconds : Int,
  nanoseconds : UInt,
) -> Result[SedpQos, String] {
  if !sedp_duration_is_valid(seconds, nanoseconds) {
    return Err("SEDP deadline duration is invalid")
  }
  Ok({
    ..self,
    deadline_seconds: seconds,
    deadline_fraction: qos_nanoseconds_to_fraction(nanoseconds),
  })
}

///|
/// Set the liveliness policy and lease duration in seconds and nanoseconds.
pub fn SedpQos::with_liveliness(
  self : SedpQos,
  kind : UInt,
  lease_seconds : Int,
  lease_nanoseconds : UInt,
) -> Result[SedpQos, String] {
  if kind > LIVELINESS_MANUAL_BY_TOPIC {
    return Err("SEDP liveliness kind is invalid")
  }
  if !sedp_duration_is_valid(lease_seconds, lease_nanoseconds) {
    return Err("SEDP liveliness lease duration is invalid")
  }
  Ok({
    ..self,
    liveliness: kind,
    liveliness_lease_seconds: lease_seconds,
    liveliness_lease_fraction: qos_nanoseconds_to_fraction(lease_nanoseconds),
  })
}

///|
fn sedp_duration_is_valid(seconds : Int, nanoseconds : UInt) -> Bool {
  seconds >= 0 &&
  (
    nanoseconds < 1_000_000_000U ||
    (
      seconds == SEDP_QOS_DURATION_INFINITE_SECONDS &&
      nanoseconds == SEDP_QOS_DURATION_INFINITE_FRACTION
    )
  )
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
/// Return the deadline seconds component.
pub fn SedpQos::deadline_seconds(self : SedpQos) -> Int {
  self.deadline_seconds
}

///|
/// Return the raw RTPS 2^-32 seconds fraction of the deadline.
pub fn SedpQos::deadline_fraction(self : SedpQos) -> UInt {
  self.deadline_fraction
}

///|
pub fn SedpQos::liveliness(self : SedpQos) -> UInt {
  self.liveliness
}

///|
/// Return the liveliness lease seconds component.
pub fn SedpQos::liveliness_lease_seconds(self : SedpQos) -> Int {
  self.liveliness_lease_seconds
}

///|
/// Return the raw RTPS 2^-32 seconds fraction of the liveliness lease.
pub fn SedpQos::liveliness_lease_fraction(self : SedpQos) -> UInt {
  self.liveliness_lease_fraction
}

///|
pub fn SedpQos::deadline_parameter(self : SedpQos) -> Parameter {
  qos_deadline_fraction(self.deadline_seconds, self.deadline_fraction)
}

///|
pub fn SedpQos::liveliness_parameter(self : SedpQos) -> Parameter {
  qos_liveliness_fraction(
    self.liveliness,
    self.liveliness_lease_seconds,
    self.liveliness_lease_fraction,
  )
}

///|
/// Best-effort fallback QoS for endpoint parameters omitted from SEDP.
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
      EntityId::new(b"\x00\x00\x01", 0xC1).unwrap(),
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
/// Read the ROS 2 RIHS01 type hash from the endpoint USER_DATA parameter.
///
/// A missing USER_DATA or typehash key is represented as `None` so endpoints
/// from ROS 2 implementations predating type-hash advertisement remain usable.
pub fn SedpEndpointData::type_hash(
  self : SedpEndpointData,
) -> Result[String?, String] {
  for parameter in self.extra_parameters {
    if parameter.id() != PID_USER_DATA {
      continue
    }
    let value = @utf8.decode(parameter.value()) catch {
      _ => return Err("SEDP USER_DATA is not valid UTF-8")
    }
    for entry in value.split(";") {
      let parts = entry.split("=").collect()
      if parts.length() == 0 || parts[0] != "typehash" {
        continue
      }
      if parts.length() != 2 || parts[1].length() == 0 {
        return Err("SEDP USER_DATA contains an invalid typehash value")
      }
      return Ok(Some(parts[1].to_owned()))
    }
  }
  Ok(None)
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
fn sedp_qos_u32_at(
  value : Bytes,
  offset : Int,
  label : String,
) -> Result[UInt, String] {
  if offset < 0 || value.length() < offset + 4 {
    return Err("SEDP " + label + " parameter is truncated")
  }
  sedp_qos_u32(
    Bytes::from_array([
      value[offset],
      value[offset + 1],
      value[offset + 2],
      value[offset + 3],
    ]),
    label,
  )
}

///|
fn sedp_qos_i32_at(
  value : Bytes,
  offset : Int,
  label : String,
) -> Result[Int, String] {
  match sedp_qos_u32_at(value, offset, label) {
    Ok(result) => Ok(result.reinterpret_as_int())
    Err(message) => Err(message)
  }
}

///|
fn sedp_qos_duration(
  value : Bytes,
  offset : Int,
  label : String,
) -> Result[(Int, UInt), String] {
  if offset < 0 || value.length() < offset + 8 {
    return Err("SEDP " + label + " duration is truncated")
  }
  let seconds = match sedp_qos_i32_at(value, offset, label + " seconds") {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  if seconds < 0 {
    return Err("SEDP " + label + " duration has negative seconds")
  }
  let fraction = match sedp_qos_u32_at(value, offset + 4, label + " fraction") {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  Ok((seconds, fraction))
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
  if length < 0 || length > (value.length() - 4) / 2 {
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
  // DDSI-RTPS uses Reliable as the publication default and Best Effort as
  // the subscription default, so Fast DDS may omit PID_RELIABILITY.
  let mut reliability = match self.kind {
    SedpEndpointKind::Publication => RELIABILITY_RELIABLE
    SedpEndpointKind::Subscription => defaults.reliability
  }
  let mut durability = defaults.durability
  let mut history = defaults.history
  let mut depth = defaults.depth
  let mut data_representation = defaults.data_representation
  let mut deadline_seconds = defaults.deadline_seconds
  let mut deadline_fraction = defaults.deadline_fraction
  let mut liveliness = defaults.liveliness
  let mut liveliness_lease_seconds = defaults.liveliness_lease_seconds
  let mut liveliness_lease_fraction = defaults.liveliness_lease_fraction
  for parameter in self.extra_parameters {
    match parameter.id() {
      PID_RELIABILITY => {
        let value = parameter.value()
        if value.length() < 12 {
          return Err("SEDP reliability parameter is truncated")
        }
        reliability = match sedp_qos_u32(value, "reliability") {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        match sedp_qos_duration(value, 4, "reliability max blocking time") {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
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
      PID_DEADLINE => {
        let (seconds, fraction) = match
          sedp_qos_duration(parameter.value(), 0, "deadline") {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        deadline_seconds = seconds
        deadline_fraction = fraction
      }
      PID_LIVELINESS => {
        let value = parameter.value()
        if value.length() < 12 {
          return Err("SEDP liveliness parameter is truncated")
        }
        liveliness = match sedp_qos_u32_at(value, 0, "liveliness") {
          Ok(value) if value <= LIVELINESS_MANUAL_BY_TOPIC => value
          Ok(_) => return Err("SEDP liveliness kind is invalid")
          Err(message) => return Err(message)
        }
        let (lease_seconds, lease_fraction) = match
          sedp_qos_duration(value, 4, "liveliness lease") {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        liveliness_lease_seconds = lease_seconds
        liveliness_lease_fraction = lease_fraction
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
  if reliability != RELIABILITY_BEST_EFFORT &&
    reliability != RELIABILITY_RELIABLE {
    return Err("SEDP reliability kind is invalid")
  }
  if durability > DURABILITY_PERSISTENT {
    return Err("SEDP durability kind is invalid")
  }
  if history != HISTORY_KEEP_LAST && history != HISTORY_KEEP_ALL {
    return Err("SEDP history kind is invalid")
  }
  if history == HISTORY_KEEP_LAST && depth <= 0 {
    return Err("SEDP keep-last history depth must be positive")
  }
  let qos = SedpQos::new(reliability, durability, history, depth).with_data_representation(
    data_representation,
  )
  Ok({
    ..qos,
    deadline_seconds,
    deadline_fraction,
    liveliness,
    liveliness_lease_seconds,
    liveliness_lease_fraction,
  })
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
fn sedp_duration_le(
  left_seconds : Int,
  left_fraction : UInt,
  right_seconds : Int,
  right_fraction : UInt,
) -> Bool {
  left_seconds < right_seconds ||
  (left_seconds == right_seconds && left_fraction <= right_fraction)
}

///|
/// Check the supported offered/requested QoS compatibility of a writer and reader.
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
    sedp_duration_le(
      offered.deadline_seconds,
      offered.deadline_fraction,
      requested.deadline_seconds,
      requested.deadline_fraction,
    ) &&
    offered.liveliness >= requested.liveliness &&
    sedp_duration_le(
      offered.liveliness_lease_seconds,
      offered.liveliness_lease_fraction,
      requested.liveliness_lease_seconds,
      requested.liveliness_lease_fraction,
    ) &&
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
/// Encode a DDS octet sequence used by PID_USER_DATA.
fn sedp_octet_sequence(value : Bytes) -> Bytes {
  let bytes : Array[Byte] = []
  let length = sedp_u32_le(value.length().reinterpret_as_uint())
  for byte in length {
    bytes.push(byte)
  }
  for byte in value {
    bytes.push(byte)
  }
  Bytes::from_array(bytes)
}

///|
/// Decode a DDS octet sequence used by PID_USER_DATA.
fn sedp_read_octet_sequence(value : Bytes) -> Result[Bytes, String] {
  if value.length() < 4 {
    return Err("SEDP USER_DATA is missing its length")
  }
  let length = match value[0:4] {
    [u32le(result)] => result.reinterpret_as_int()
    _ => return Err("SEDP USER_DATA has an invalid length")
  }
  if length < 0 || length > value.length() - 4 {
    return Err("SEDP USER_DATA length is outside the parameter")
  }
  let bytes : Array[Byte] = []
  for byte in value[4:4 + length] {
    bytes.push(byte)
  }
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
  if length <= 0 || length > value.length() - 4 {
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
    if parameter.id() == PID_USER_DATA {
      parameters.add(
        Parameter::new(PID_USER_DATA, sedp_octet_sequence(parameter.value())),
      )
    } else {
      parameters.add(parameter)
    }
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
/// Build a key-only SEDP DATA sample that removes this endpoint.
pub fn SedpEndpointData::to_dispose_data_submessage(
  self : SedpEndpointData,
  reader_id : EntityId,
  writer_id : EntityId,
  writer_sequence_number : Int64,
) -> DataSubmessage {
  DataSubmessage::new(reader_id, writer_id, writer_sequence_number, b"")
  .with_key(self.endpoint_guid.to_bytes())
  .with_status_info(STATUS_INFO_DISPOSED | STATUS_INFO_UNREGISTERED)
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
  let parameters = match
    ParameterList::from_data_bytes(data.serialized_payload()) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  SedpEndpointData::from_parameter_list(kind, parameters)
}

///|
/// Parse the endpoint GUID from a key-only SEDP DATA submessage.
pub fn SedpEndpointData::endpoint_guid_from_key_data(
  data : DataSubmessage,
) -> Result[Guid, String] {
  if (data.flags() & DATA_FLAG_KEY) == 0 {
    return Err("the SEDP DATA submessage does not contain a key")
  }
  Guid::from_bytes(data.serialized_payload())
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
        EntityId::new(b"\x00\x00\x01", 0xC1).unwrap(),
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
      PID_USER_DATA =>
        result.extra_parameters.push(
          Parameter::new(
            PID_USER_DATA,
            match sedp_read_octet_sequence(parameter.value()) {
              Ok(value) => value
              Err(message) => return Err(message)
            },
          ),
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
