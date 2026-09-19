///|
/// Runtime settings shared by the native ROS 2 interoperability examples.
pub struct Config {
  ip : UInt
  domain_id : UInt
}

///|
fn parse_uint(value : String, name : String) -> Result[UInt, String] {
  let parsed = @string.parse_int(value) catch {
    _ => return Err(name + " must be a decimal unsigned integer")
  }
  if parsed < 0 {
    return Err(name + " must be a decimal unsigned integer")
  }
  Ok(parsed.reinterpret_as_uint())
}

///|
fn parse_ipv4(value : String) -> Result[UInt, String] {
  let parts = value.split(".").collect()
  if parts.length() != 4 {
    return Err("ROS2_MBT_IP must be an IPv4 address")
  }
  let mut result = 0U
  for part in parts {
    let octet = @string.parse_int(part) catch {
      _ => return Err("ROS2_MBT_IP must be an IPv4 address")
    }
    if octet < 0 || octet > 255 {
      return Err("ROS2_MBT_IP must be an IPv4 address")
    }
    result = (result << 8) | octet.reinterpret_as_uint()
  }
  Ok(result)
}

///|
/// Read example settings from the process environment.
///
/// `ROS2_MBT_IP` is the local IPv4 address advertised in DDSI locators. It
/// defaults to loopback for local tests. `ROS_DOMAIN_ID` defaults to domain 0.
pub fn load() -> Result[Config, String] {
  let ip = match @env.get_env_var("ROS2_MBT_IP") {
    Some(value) =>
      match parse_ipv4(value) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
    None => 0x7F000001U
  }
  let domain_id = match @env.get_env_var("ROS_DOMAIN_ID") {
    Some(value) =>
      match parse_uint(value, "ROS_DOMAIN_ID") {
        Ok(value) => value
        Err(message) => return Err(message)
      }
    None => 0U
  }
  Ok({ ip, domain_id, })
}

///|
test "parse settings" {
  assert_eq(parse_ipv4("192.168.1.20"), Ok(0xC0A80114U))
  assert_eq(parse_uint("7", "ROS_DOMAIN_ID"), Ok(7U))
}

///|
test "reject invalid settings" {
  assert_true(parse_ipv4("192.168.1.256") is Err(_))
  assert_true(parse_ipv4("192.168.1") is Err(_))
  assert_true(parse_uint("-1", "ROS_DOMAIN_ID") is Err(_))
}
