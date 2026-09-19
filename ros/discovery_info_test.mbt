///|
test "ROS discovery info round trips participant and node entities" {
  let gid = match Gid::new(b"0123456789abcdef") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let reader_gid = match Gid::new(b"reader-entity-01") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let writer_gid = match Gid::new(b"writer-entity-01") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let node = match NodeEntitiesInfo::new("/demo", "talker") {
    Ok(value) => value
    Err(message) => fail(message)
  }
  node.add_reader_gid(reader_gid)
  node.add_writer_gid(writer_gid)
  let participant = ParticipantEntitiesInfo::new(gid)
  participant.add_node(node)
  let encoded = participant.to_cdr_bytes()
  let decoded = match ParticipantEntitiesInfo::from_cdr_bytes(encoded) {
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
  assert_true(Gid::new(b"short") is Err(_))
  assert_true(NodeEntitiesInfo::new(String::repeat("x", 257), "node") is Err(_))
}
