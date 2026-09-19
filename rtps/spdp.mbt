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
  protocol_version : ProtocolVersion
  vendor_id : VendorId
  participant_guid : Guid
  domain_id : UInt
  lease_seconds : Int
  lease_nanoseconds : UInt
  builtin_endpoint_set : UInt
  metatraffic_unicast_locators : Array[Locator]
  metatraffic_multicast_locators : Array[Locator]
  default_unicast_locators : Array[Locator]
  default_multicast_locators : Array[Locator]
}

///|
/// Create SPDP participant data with empty locator lists.
pub fn SpdpParticipantData::new(
  participant_guid : Guid,
  vendor_id : VendorId,
  domain_id : UInt,
  lease_seconds : Int,
  lease_nanoseconds : UInt,
  builtin_endpoint_set : UInt,
) -> SpdpParticipantData {
  {
    protocol_version: ProtocolVersion::new(
      PROTOCOL_VERSION_MAJOR,
      PROTOCOL_VERSION_MINOR,
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
pub fn SpdpParticipantData::add_metatraffic_unicast(
  self : SpdpParticipantData,
  locator : Locator,
) -> Unit {
  self.metatraffic_unicast_locators.push(locator)
}

///|
pub fn SpdpParticipantData::add_metatraffic_multicast(
  self : SpdpParticipantData,
  locator : Locator,
) -> Unit {
  self.metatraffic_multicast_locators.push(locator)
}

///|
pub fn SpdpParticipantData::add_default_unicast(
  self : SpdpParticipantData,
  locator : Locator,
) -> Unit {
  self.default_unicast_locators.push(locator)
}

///|
pub fn SpdpParticipantData::add_default_multicast(
  self : SpdpParticipantData,
  locator : Locator,
) -> Unit {
  self.default_multicast_locators.push(locator)
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
  let nanoseconds_bytes = spdp_u32_le(nanoseconds)
  for i in 0..<4 {
    bytes.push(seconds_bytes[i])
  }
  for i in 0..<4 {
    bytes.push(nanoseconds_bytes[i])
  }
  Bytes::from_array(bytes)
}

///|
fn spdp_add_locators(
  parameters : ParameterList,
  id : UInt16,
  locators : Array[Locator],
) -> Unit {
  for locator in locators {
    parameters.add(Parameter::new(id, locator.to_bytes()))
  }
}

///|
/// Convert the participant data to the RTPS parameter list used by SPDP.
pub fn SpdpParticipantData::to_parameter_list(
  self : SpdpParticipantData,
) -> ParameterList {
  let parameters = ParameterList::new()
  parameters.add(
    Parameter::new(
      PID_PROTOCOL_VERSION,
      Bytes::from_array([
        self.protocol_version.major,
        self.protocol_version.minor,
        0,
        0,
      ]),
    ),
  )
  parameters.add(
    Parameter::new(
      PID_VENDOR_ID,
      Bytes::from_array([self.vendor_id.major, self.vendor_id.minor, 0, 0]),
    ),
  )
  parameters.add(
    Parameter::new(PID_PARTICIPANT_GUID, self.participant_guid.to_bytes()),
  )
  parameters.add(
    Parameter::new(
      PID_PARTICIPANT_LEASE_DURATION,
      spdp_duration(self.lease_seconds, self.lease_nanoseconds),
    ),
  )
  parameters.add(Parameter::new(PID_DOMAIN_ID, spdp_u32_le(self.domain_id)))
  spdp_add_locators(
    parameters,
    PID_METATRAFFIC_UNICAST_LOCATOR,
    self.metatraffic_unicast_locators,
  )
  spdp_add_locators(
    parameters,
    PID_METATRAFFIC_MULTICAST_LOCATOR,
    self.metatraffic_multicast_locators,
  )
  spdp_add_locators(
    parameters,
    PID_DEFAULT_UNICAST_LOCATOR,
    self.default_unicast_locators,
  )
  spdp_add_locators(
    parameters,
    PID_DEFAULT_MULTICAST_LOCATOR,
    self.default_multicast_locators,
  )
  parameters.add(
    Parameter::new(
      PID_BUILTIN_ENDPOINT_SET,
      spdp_u32_le(self.builtin_endpoint_set),
    ),
  )
  parameters
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
  reader_id : EntityId,
  writer_id : EntityId,
  writer_sequence_number : Int64,
) -> DataSubmessage {
  DataSubmessage::new(
    reader_id,
    writer_id,
    writer_sequence_number,
    self.to_cdr_bytes(),
  )
}
