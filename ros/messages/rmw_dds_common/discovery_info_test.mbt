///|
test "ROS discovery info round trips participant and node entities" {
  let gid = match @rmw_dds_common.Gid::new(b"0123456789abcdef") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let reader_gid = match @rmw_dds_common.Gid::new(b"reader-entity-01") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_gid = match @rmw_dds_common.Gid::new(b"writer-entity-01") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let node = match @rmw_dds_common.NodeEntitiesInfo::new("/demo", "talker") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  node.add_reader_gid(reader_gid)
  node.add_writer_gid(writer_gid)
  let participant = @rmw_dds_common.ParticipantEntitiesInfo::new(gid)
  participant.add_node(node)
  let encoded = participant.to_cdr_bytes()
  assert_eq(
    encoded, b"\x00\x01\x00\x000123456789abcdef\x01\x00\x00\x00\x06\x00\x00\x00/demo\x00\x00\x00\x07\x00\x00\x00talker\x00\x00\x01\x00\x00\x00reader-entity-01\x01\x00\x00\x00writer-entity-01",
  )
  let decoded = match
    @rmw_dds_common.ParticipantEntitiesInfo::from_cdr_bytes(encoded) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded.gid(), gid)
  assert_eq(decoded.node_entities_info_seq().length(), 1)
  let decoded_node = decoded.node_entities_info_seq()[0]
  assert_eq(decoded_node.node_namespace(), "/demo")
  assert_eq(decoded_node.node_name(), "talker")
  assert_eq(decoded_node.reader_gid_seq(), [reader_gid])
  assert_eq(decoded_node.writer_gid_seq(), [writer_gid])
  assert_eq(decoded.to_cdr_bytes(), encoded)
}

///|
test "ROS discovery info rejects oversized names and GIDs" {
  assert_true(@rmw_dds_common.Gid::new(b"short") is Err(_))
  assert_true(
    @rmw_dds_common.NodeEntitiesInfo::new(String::repeat("x", 257), "node")
    is Err(_),
  )
}
