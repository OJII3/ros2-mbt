///|
fn builtin_builtin_interfaces_message_source(type_name : String) -> String? {
  match type_name {
    "Duration" => Some("int32 sec\nuint32 nanosec\n")
    "Time" => Some("int32 sec\nuint32 nanosec\n")
    _ => None
  }
}
