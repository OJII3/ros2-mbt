///|
/// ROS 2 entity-name kinds that use distinct DDS topic prefixes.
pub(all) enum DdsTopicKind {
  Topic
  ServiceRequest
  ServiceResponse
} derive(Eq, Debug)

///|
fn validate_name(value : String, label : String) -> Result[Unit, String] {
  if value.length() == 0 {
    Err("ROS " + label + " must not be empty")
  } else {
    Ok(())
  }
}

///|
/// Convert a ROS topic or service name to its DDS-mangled topic name.
pub fn ros_name_to_dds(
  name : String,
  kind : DdsTopicKind,
) -> Result[String, String] {
  match validate_name(name, "name") {
    Err(message) => return Err(message)
    Ok(_) => ()
  }
  let prefix = match kind {
    DdsTopicKind::Topic => "rt/"
    DdsTopicKind::ServiceRequest => "rq/"
    DdsTopicKind::ServiceResponse => "rr/"
  }
  if name[0] == '/' {
    Ok(prefix + name[1:].to_owned())
  } else {
    Ok(prefix + name)
  }
}

///|
/// Convert a ROS topic name to its DDS topic name.
pub fn ros_topic_to_dds(name : String) -> Result[String, String] {
  ros_name_to_dds(name, DdsTopicKind::Topic)
}

///|
/// Convert a ROS service name to its DDS request topic name.
pub fn ros_service_request_to_dds(name : String) -> Result[String, String] {
  ros_name_to_dds(name, DdsTopicKind::ServiceRequest)
}

///|
/// Convert a ROS service name to its DDS response topic name.
pub fn ros_service_response_to_dds(name : String) -> Result[String, String] {
  ros_name_to_dds(name, DdsTopicKind::ServiceResponse)
}

///|
/// Convert a ROS interface type to the Fast DDS/Cyclone DDS type name used by ROS 2.
pub fn ros_type_to_dds(
  package_name : String,
  interface_namespace : String,
  type_name : String,
) -> Result[String, String] {
  match validate_name(package_name, "package name") {
    Err(message) => return Err(message)
    Ok(_) => ()
  }
  match validate_name(interface_namespace, "interface namespace") {
    Err(message) => return Err(message)
    Ok(_) => ()
  }
  match validate_name(type_name, "type name") {
    Err(message) => return Err(message)
    Ok(_) => ()
  }
  Ok(package_name + "::" + interface_namespace + "::dds_::" + type_name + "_")
}

///|
/// Convert a `package/msg/Type`-like path to its ROS 2 DDS type name.
pub fn ros_type_path_to_dds(path : String) -> Result[String, String] {
  let parts = path.split("/").collect()
  if parts.length() != 3 {
    return Err("a ROS type path must contain package/namespace/type")
  }
  ros_type_to_dds(parts[0].to_owned(), parts[1].to_owned(), parts[2].to_owned())
}
