///|
/// Built-in endpoint bit for the SPDP participant announcer.
pub const BUILTIN_ENDPOINT_PARTICIPANT_ANNOUNCER : UInt = 0x00000001

///|
/// Built-in endpoint bit for the SPDP participant detector.
pub const BUILTIN_ENDPOINT_PARTICIPANT_DETECTOR : UInt = 0x00000002

///|
/// Built-in endpoint bit for the SEDP publications announcer.
pub const BUILTIN_ENDPOINT_PUBLICATIONS_ANNOUNCER : UInt = 0x00000004

///|
/// Built-in endpoint bit for the SEDP publications detector.
pub const BUILTIN_ENDPOINT_PUBLICATIONS_DETECTOR : UInt = 0x00000008

///|
/// Built-in endpoint bit for the SEDP subscriptions announcer.
pub const BUILTIN_ENDPOINT_SUBSCRIPTIONS_ANNOUNCER : UInt = 0x00000010

///|
/// Built-in endpoint bit for the SEDP subscriptions detector.
pub const BUILTIN_ENDPOINT_SUBSCRIPTIONS_DETECTOR : UInt = 0x00000020

///|
/// EntityId for the SPDP participant writer.
pub const ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER : Byte = 0xC2

///|
/// EntityId for the SPDP participant reader.
pub const ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER : Byte = 0xC7

///|
/// The participant discovery data needed to construct an SPDP announcement.
pub struct SpdpParticipantData {
  protocol_version : @core.ProtocolVersion
  vendor_id : @core.VendorId
  participant_guid : @core.Guid
  domain_id : UInt
  lease_seconds : Int
  lease_nanoseconds : UInt
  builtin_endpoint_set : UInt
  metatraffic_unicast_locators : Array[@core.Locator]
  metatraffic_multicast_locators : Array[@core.Locator]
  default_unicast_locators : Array[@core.Locator]
  default_multicast_locators : Array[@core.Locator]
}

///|
/// Create SPDP participant data with empty locator lists.
pub fn SpdpParticipantData::new(
  participant_guid : @core.Guid,
  vendor_id : @core.VendorId,
  domain_id : UInt,
  lease_seconds : Int,
  lease_nanoseconds : UInt,
  builtin_endpoint_set : UInt,
) -> SpdpParticipantData {
  {
    protocol_version: @core.ProtocolVersion::new(
      @core.PROTOCOL_VERSION_MAJOR,
      @core.PROTOCOL_VERSION_MINOR,
    ),
    vendor_id,
    participant_guid,
    domain_id,
    lease_seconds,
    lease_nanoseconds,
    builtin_endpoint_set,
    metatraffic_unicast_locators: [],
    metatraffic_multicast_locators: [],
    default_unicast_locators: [],
    default_multicast_locators: [],
  }
}

///|
/// Add a metatraffic unicast locator.
pub fn SpdpParticipantData::add_metatraffic_unicast(
  self : SpdpParticipantData,
  locator : @core.Locator,
) -> Unit {
  self.metatraffic_unicast_locators.push(locator)
}

///|
/// Add a metatraffic multicast locator.
pub fn SpdpParticipantData::add_metatraffic_multicast(
  self : SpdpParticipantData,
  locator : @core.Locator,
) -> Unit {
  self.metatraffic_multicast_locators.push(locator)
}

///|
/// Add a default unicast locator.
pub fn SpdpParticipantData::add_default_unicast(
  self : SpdpParticipantData,
  locator : @core.Locator,
) -> Unit {
  self.default_unicast_locators.push(locator)
}

///|
/// Add a default multicast locator.
pub fn SpdpParticipantData::add_default_multicast(
  self : SpdpParticipantData,
  locator : @core.Locator,
) -> Unit {
  self.default_multicast_locators.push(locator)
}

///|
/// Return the participant GUID.
pub fn SpdpParticipantData::participant_guid(
  self : SpdpParticipantData,
) -> @core.Guid {
  self.participant_guid
}

///|
/// Return the vendor identifier.
pub fn SpdpParticipantData::vendor_id(
  self : SpdpParticipantData,
) -> @core.VendorId {
  self.vendor_id
}

///|
/// Return the DDS domain identifier.
pub fn SpdpParticipantData::domain_id(self : SpdpParticipantData) -> UInt {
  self.domain_id
}

///|
/// Return the participant lease duration in seconds.
pub fn SpdpParticipantData::lease_seconds(self : SpdpParticipantData) -> Int {
  self.lease_seconds
}

///|
/// Return the participant lease duration in nanoseconds.
pub fn SpdpParticipantData::lease_nanoseconds(
  self : SpdpParticipantData,
) -> UInt {
  self.lease_nanoseconds
}

///|
/// Return the enabled builtin endpoint set.
pub fn SpdpParticipantData::builtin_endpoint_set(
  self : SpdpParticipantData,
) -> UInt {
  self.builtin_endpoint_set
}

///|
/// Return the metatraffic unicast locators.
pub fn SpdpParticipantData::metatraffic_unicast_locators(
  self : SpdpParticipantData,
) -> Array[@core.Locator] {
  self.metatraffic_unicast_locators
}

///|
/// Return the metatraffic multicast locators.
pub fn SpdpParticipantData::metatraffic_multicast_locators(
  self : SpdpParticipantData,
) -> Array[@core.Locator] {
  self.metatraffic_multicast_locators
}

///|
/// Return the default unicast locators.
pub fn SpdpParticipantData::default_unicast_locators(
  self : SpdpParticipantData,
) -> Array[@core.Locator] {
  self.default_unicast_locators
}

///|
/// Return the default multicast locators.
pub fn SpdpParticipantData::default_multicast_locators(
  self : SpdpParticipantData,
) -> Array[@core.Locator] {
  self.default_multicast_locators
}

///|
fn spdp_u32_le(value : UInt) -> Bytes {
  Bytes::from_array([
    value.to_byte(),
    (value >> 8).to_byte(),
    (value >> 16).to_byte(),
    (value >> 24).to_byte(),
  ])
}

///|
fn spdp_i32_le(value : Int) -> Bytes {
  spdp_u32_le(value.reinterpret_as_uint())
}

///|
fn spdp_duration(seconds : Int, nanoseconds : UInt) -> Bytes {
  let bytes : Array[Byte] = []
  let seconds_bytes = spdp_i32_le(seconds)
  let fraction = if nanoseconds == 0xFFFFFFFFU {
    nanoseconds
  } else {
    qos_nanoseconds_to_fraction(nanoseconds)
  }
  let fraction_bytes = spdp_u32_le(fraction)
  for i in 0..<4 {
    bytes.push(seconds_bytes[i])
  }
  for i in 0..<4 {
    bytes.push(fraction_bytes[i])
  }
  Bytes::from_array(bytes)
}

///|
fn spdp_read_u32(value : Bytes) -> Result[UInt, String] {
  if value.length() != 4 {
    return Err("an SPDP uint32 parameter must contain 4 bytes")
  }
  match value {
    [u32le(result)] => Ok(result)
    _ => Err("invalid SPDP uint32 parameter")
  }
}

///|
fn spdp_read_protocol_version(
  value : Bytes,
) -> Result[@core.ProtocolVersion, String] {
  if value.length() != 4 {
    return Err("an SPDP protocol version must contain 4 bytes")
  }
  Ok(@core.ProtocolVersion::new(value[0], value[1]))
}

///|
fn spdp_read_vendor_id(value : Bytes) -> Result[@core.VendorId, String] {
  if value.length() != 4 {
    return Err("an SPDP vendor ID must contain 4 bytes")
  }
  Ok(@core.VendorId::new(value[0], value[1]))
}

///|
fn spdp_read_duration(value : Bytes) -> Result[(Int, UInt), String] {
  if value.length() != 8 {
    return Err("an SPDP lease duration must contain 8 bytes")
  }
  let seconds = match value[0:4] {
    [u32le(result)] => result
    _ => return Err("invalid SPDP lease duration")
  }
  let nanoseconds = match value[4:8] {
    [u32le(result)] => result
    _ => return Err("invalid SPDP lease duration")
  }
  Ok(
    (
      seconds.reinterpret_as_int(),
      if nanoseconds == 0xFFFFFFFFU {
        nanoseconds
      } else {
        qos_fraction_to_nanoseconds(nanoseconds)
      },
    ),
  )
}

///|
fn spdp_add_locators(
  parameters : @core.ParameterList,
  id : UInt16,
  locators : Array[@core.Locator],
) -> Unit {
  for locator in locators {
    parameters.add(@core.Parameter::new(id, locator.to_bytes()))
  }
}

///|
/// Convert the participant data to the RTPS parameter list used by SPDP.
pub fn SpdpParticipantData::to_parameter_list(
  self : SpdpParticipantData,
) -> @core.ParameterList {
  let parameters = @core.ParameterList::new()
  parameters.add(
    @core.Parameter::new(
      @core.PID_PROTOCOL_VERSION,
      Bytes::from_array([
        self.protocol_version.major,
        self.protocol_version.minor,
        0,
        0,
      ]),
    ),
  )
  parameters.add(
    @core.Parameter::new(
      @core.PID_VENDOR_ID,
      Bytes::from_array([self.vendor_id.major, self.vendor_id.minor, 0, 0]),
    ),
  )
  parameters.add(
    @core.Parameter::new(
      @core.PID_PARTICIPANT_GUID,
      self.participant_guid.to_bytes(),
    ),
  )
  parameters.add(
    @core.Parameter::new(
      @core.PID_PARTICIPANT_LEASE_DURATION,
      spdp_duration(self.lease_seconds, self.lease_nanoseconds),
    ),
  )
  parameters.add(
    @core.Parameter::new(@core.PID_DOMAIN_ID, spdp_u32_le(self.domain_id)),
  )
  spdp_add_locators(
    parameters,
    @core.PID_METATRAFFIC_UNICAST_LOCATOR,
    self.metatraffic_unicast_locators,
  )
  spdp_add_locators(
    parameters,
    @core.PID_METATRAFFIC_MULTICAST_LOCATOR,
    self.metatraffic_multicast_locators,
  )
  spdp_add_locators(
    parameters,
    @core.PID_DEFAULT_UNICAST_LOCATOR,
    self.default_unicast_locators,
  )
  spdp_add_locators(
    parameters,
    @core.PID_DEFAULT_MULTICAST_LOCATOR,
    self.default_multicast_locators,
  )
  parameters.add(
    @core.Parameter::new(
      @core.PID_BUILTIN_ENDPOINT_SET,
      spdp_u32_le(self.builtin_endpoint_set),
    ),
  )
  parameters
}

///|
/// Parse SPDP participant data from its RTPS parameter list.
pub fn SpdpParticipantData::from_parameter_list(
  parameters : @core.ParameterList,
) -> Result[SpdpParticipantData, String] {
  SpdpParticipantData::from_parameter_list_with_default_domain(parameters, 0U)
}

///|
/// Parse SPDP participant data, using the receiving domain when PID_DOMAIN_ID
/// is omitted by the remote implementation.
fn SpdpParticipantData::from_parameter_list_with_default_domain(
  parameters : @core.ParameterList,
  default_domain_id : UInt,
) -> Result[SpdpParticipantData, String] {
  let mut protocol_version = @core.ProtocolVersion::new(
    @core.PROTOCOL_VERSION_MAJOR,
    @core.PROTOCOL_VERSION_MINOR,
  )
  let mut vendor_id = @core.VendorId::new(0, 0)
  let mut participant_guid_bytes = b""
  let mut domain_id = default_domain_id
  let mut lease_seconds : Int = 0
  let mut lease_nanoseconds : UInt = 0
  let mut builtin_endpoint_set : UInt = 0
  let mut has_participant_guid = false
  let metatraffic_unicast_locators : Array[@core.Locator] = []
  let metatraffic_multicast_locators : Array[@core.Locator] = []
  let default_unicast_locators : Array[@core.Locator] = []
  let default_multicast_locators : Array[@core.Locator] = []
  for parameter in parameters.values() {
    let value = parameter.value()
    match parameter.id() {
      @core.PID_PROTOCOL_VERSION =>
        protocol_version = match spdp_read_protocol_version(value) {
          Ok(result) => result
          Err(message) => return Err(message)
        }
      @core.PID_VENDOR_ID =>
        vendor_id = match spdp_read_vendor_id(value) {
          Ok(result) => result
          Err(message) => return Err(message)
        }
      @core.PID_PARTICIPANT_GUID => {
        participant_guid_bytes = value
        has_participant_guid = true
      }
      @core.PID_PARTICIPANT_LEASE_DURATION => {
        let duration = match spdp_read_duration(value) {
          Ok(result) => result
          Err(message) => return Err(message)
        }
        lease_seconds = duration.0
        lease_nanoseconds = duration.1
      }
      @core.PID_DOMAIN_ID =>
        domain_id = match spdp_read_u32(value) {
          Ok(result) => result
          Err(message) => return Err(message)
        }
      @core.PID_BUILTIN_ENDPOINT_SET =>
        builtin_endpoint_set = match spdp_read_u32(value) {
          Ok(result) => result
          Err(message) => return Err(message)
        }
      @core.PID_METATRAFFIC_UNICAST_LOCATOR =>
        metatraffic_unicast_locators.push(
          match @core.Locator::from_bytes(value) {
            Ok(result) => result
            Err(message) => return Err(message)
          },
        )
      @core.PID_METATRAFFIC_MULTICAST_LOCATOR =>
        metatraffic_multicast_locators.push(
          match @core.Locator::from_bytes(value) {
            Ok(result) => result
            Err(message) => return Err(message)
          },
        )
      @core.PID_DEFAULT_UNICAST_LOCATOR =>
        default_unicast_locators.push(
          match @core.Locator::from_bytes(value) {
            Ok(result) => result
            Err(message) => return Err(message)
          },
        )
      @core.PID_DEFAULT_MULTICAST_LOCATOR =>
        default_multicast_locators.push(
          match @core.Locator::from_bytes(value) {
            Ok(result) => result
            Err(message) => return Err(message)
          },
        )
      _ => ()
    }
  }
  if !has_participant_guid {
    return Err("SPDP participant data is missing PID_PARTICIPANT_GUID")
  }
  if lease_seconds < 0 ||
    (lease_nanoseconds == 0xFFFFFFFFU && lease_seconds != 0x7FFFFFFF) {
    return Err("SPDP participant lease duration is invalid")
  }
  let participant_guid = match @core.Guid::from_bytes(participant_guid_bytes) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  Ok({
    protocol_version,
    vendor_id,
    participant_guid,
    domain_id,
    lease_seconds,
    lease_nanoseconds,
    builtin_endpoint_set,
    metatraffic_unicast_locators,
    metatraffic_multicast_locators,
    default_unicast_locators,
    default_multicast_locators,
  })
}

///|
/// Parse a CDR little-endian SPDP participant payload.
pub fn SpdpParticipantData::from_cdr_bytes(
  input : Bytes,
) -> Result[SpdpParticipantData, String] {
  let parameters = match @core.ParameterList::from_cdr_bytes(input) {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  SpdpParticipantData::from_parameter_list(parameters)
}

///|
/// Parse an SPDP participant DATA submessage.
pub fn SpdpParticipantData::from_data_submessage(
  data : @core.DataSubmessage,
) -> Result[SpdpParticipantData, String] {
  let parameters = match
    @core.ParameterList::from_data_bytes(data.serialized_payload()) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  SpdpParticipantData::from_parameter_list(parameters)
}

///|
/// Parse an SPDP DATA submessage, defaulting an omitted domain ID to the
/// domain on which the packet was received.
pub fn SpdpParticipantData::from_data_submessage_with_default_domain(
  data : @core.DataSubmessage,
  default_domain_id : UInt,
) -> Result[SpdpParticipantData, String] {
  let parameters = match
    @core.ParameterList::from_data_bytes(data.serialized_payload()) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  SpdpParticipantData::from_parameter_list_with_default_domain(
    parameters, default_domain_id,
  )
}

///|
/// Parse the participant GUID from a key-only SPDP DATA submessage.
pub fn SpdpParticipantData::participant_guid_from_key_data(
  data : @core.DataSubmessage,
) -> Result[@core.Guid, String] {
  if (data.flags() & @core.DATA_FLAG_KEY) == 0 {
    return Err("the SPDP DATA submessage does not contain a key")
  }
  @core.Guid::from_bytes(data.serialized_payload())
}

///|
/// Serialize the SPDP participant data as a CDR little-endian payload.
pub fn SpdpParticipantData::to_cdr_bytes(self : SpdpParticipantData) -> Bytes {
  self.to_parameter_list().to_cdr_bytes()
}

///|
/// Build the DATA submessage used for an SPDP announcement.
pub fn SpdpParticipantData::to_data_submessage(
  self : SpdpParticipantData,
  reader_id : @core.EntityId,
  writer_id : @core.EntityId,
  writer_sequence_number : Int64,
) -> @core.DataSubmessage {
  @core.DataSubmessage::new(
    reader_id,
    writer_id,
    writer_sequence_number,
    self.to_cdr_bytes(),
  )
}

///|
/// Build a key-only SPDP DATA sample that removes this participant.
pub fn SpdpParticipantData::to_dispose_data_submessage(
  self : SpdpParticipantData,
  reader_id : @core.EntityId,
  writer_id : @core.EntityId,
  writer_sequence_number : Int64,
) -> @core.DataSubmessage {
  @core.DataSubmessage::new(reader_id, writer_id, writer_sequence_number, b"")
  .with_key(self.participant_guid.to_bytes())
  .with_status_info(@core.STATUS_INFO_DISPOSED | @core.STATUS_INFO_UNREGISTERED)
}

///|
/// Build an RTPS message containing one SPDP participant announcement.
pub fn SpdpParticipantData::to_message(
  self : SpdpParticipantData,
  reader_id : @core.EntityId,
  writer_id : @core.EntityId,
  writer_sequence_number : Int64,
) -> @core.Message {
  let message = @core.Message::new(
    @core.Header::new(self.participant_guid.prefix(), self.vendor_id),
  )
  message.add(
    self
    .to_data_submessage(reader_id, writer_id, writer_sequence_number)
    .to_submessage(),
  )
  message
}
