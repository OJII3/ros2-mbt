///|
fn builtin_unique_identifier_msgs_message_source(type_name : String) -> String? {
  match type_name {
    "UUID" => Some("uint8[16] uuid\n")
    _ => None
  }
}
