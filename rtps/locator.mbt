///|
/// The size of an RTPS Locator_t value in bytes.
pub const LOCATOR_LENGTH : Int = 24

///|
/// Locator kind for UDP over IPv4.
pub const LOCATOR_KIND_UDP_V4 : Int = 1

///|
/// Locator kind for UDP over IPv6.
pub const LOCATOR_KIND_UDP_V6 : Int = 2

///|
/// An RTPS locator containing a transport kind, port, and 16-byte address.
pub struct Locator {
  kind : Int
  port : UInt
  address : Bytes
} derive(Eq, Debug)

///|
/// Create a locator from its wire-format fields.
pub fn Locator::new(
  kind : Int,
  port : UInt,
  address : Bytes,
) -> Result[Locator, String] {
  if address.length() != 16 {
    Err("an RTPS locator address must contain exactly 16 bytes")
  } else {
    Ok({ kind, port, address, })
  }
}

///|
/// Create a UDP/IPv4 locator from a four-byte network address.
pub fn Locator::udp_v4(address : Bytes, port : UInt) -> Result[Locator, String] {
  if address.length() != 4 {
    return Err("an IPv4 locator address must contain exactly 4 bytes")
  }
  let full_address : Array[Byte] = [
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    address[0],
    address[1],
    address[2],
    address[3],
  ]
  Locator::new(LOCATOR_KIND_UDP_V4, port, Bytes::from_array(full_address))
}

///|
pub fn Locator::kind(self : Locator) -> Int {
  self.kind
}

///|
pub fn Locator::port(self : Locator) -> UInt {
  self.port
}

///|
pub fn Locator::address(self : Locator) -> Bytes {
  self.address
}

///|
/// Serialize an RTPS Locator_t using little-endian integer fields.
pub fn Locator::to_bytes(self : Locator) -> Bytes {
  let kind = self.kind.reinterpret_as_uint()
  let port = self.port
  let bytes : Array[Byte] = [
    kind.to_byte(),
    (kind >> 8).to_byte(),
    (kind >> 16).to_byte(),
    (kind >> 24).to_byte(),
    port.to_byte(),
    (port >> 8).to_byte(),
    (port >> 16).to_byte(),
    (port >> 24).to_byte(),
  ]
  for i in 0..<16 {
    bytes.push(self.address[i])
  }
  Bytes::from_array(bytes)
}

///|
/// Parse one RTPS Locator_t value.
pub fn Locator::from_bytes(input : Bytes) -> Result[Locator, String] {
  if input.length() != LOCATOR_LENGTH {
    return Err("an RTPS locator is 24 bytes")
  }
  let kind_value : UInt = input[0].to_int().reinterpret_as_uint() |
    (input[1].to_int().reinterpret_as_uint() << 8) |
    (input[2].to_int().reinterpret_as_uint() << 16) |
    (input[3].to_int().reinterpret_as_uint() << 24)
  let port : UInt = input[4].to_int().reinterpret_as_uint() |
    (input[5].to_int().reinterpret_as_uint() << 8) |
    (input[6].to_int().reinterpret_as_uint() << 16) |
    (input[7].to_int().reinterpret_as_uint() << 24)
  let address : Array[Byte] = []
  for i in 0..<16 {
    address.push(input[8 + i])
  }
  Locator::new(
    kind_value.reinterpret_as_int(),
    port,
    Bytes::from_array(address),
  )
}
