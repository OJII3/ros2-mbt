///|
fn builtin_message_source(package_name : String, type_name : String) -> String? {
  match package_name {
    "action_msgs" => builtin_action_msgs_message_source(type_name)
    "builtin_interfaces" => builtin_builtin_interfaces_message_source(type_name)
    "geometry_msgs" => builtin_geometry_msgs_message_source(type_name)
    "nav_msgs" => builtin_nav_msgs_message_source(type_name)
    "rmw_dds_common" => builtin_rmw_dds_common_message_source(type_name)
    "sensor_msgs" => builtin_sensor_msgs_message_source(type_name)
    "std_msgs" => builtin_std_msgs_message_source(type_name)
    "unique_identifier_msgs" =>
      builtin_unique_identifier_msgs_message_source(type_name)
    _ => None
  }
}
