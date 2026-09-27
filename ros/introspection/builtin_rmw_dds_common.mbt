///|
fn builtin_rmw_dds_common_message_source(type_name : String) -> String? {
  match type_name {
    "Gid" => Some("char[16] data\n")
    "NodeEntitiesInfo" =>
      Some(
        "string<=256 node_namespace\nstring<=256 node_name\nGid[] reader_gid_seq\nGid[] writer_gid_seq\n",
      )
    "ParticipantEntitiesInfo" =>
      Some("Gid gid\nNodeEntitiesInfo[] node_entities_info_seq\n")
    _ => None
  }
}
