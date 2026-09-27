///|
fn builtin_std_msgs_message_source(type_name : String) -> String? {
  match type_name {
    "Header" => Some("builtin_interfaces/Time stamp\nstring frame_id\n")
    "String" => Some("string data\n")
    _ => None
  }
}
