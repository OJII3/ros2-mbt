///|
fn write_test_u16_le(buffer : Buffer, value : UInt32) -> Unit {
  buffer.write_byte(value.to_uint16().to_byte())
  buffer.write_byte((value >> 8).to_uint16().to_byte())
}

///|
fn write_test_string(buffer : Buffer, value : StringView) -> Unit {
  let bytes = @utf8.encode(value)
  buffer.write_uint_le(bytes.length().reinterpret_as_uint())
  buffer.write_bytes(bytes)
}

///|
fn write_test_record(buffer : Buffer, opcode : Byte, payload : Bytes) -> Unit {
  buffer.write_byte(opcode)
  buffer.write_uint64_le(payload.length().reinterpret_as_uint().to_uint64())
  buffer.write_bytes(payload)
}

///|
async fn write_test_mcap(
  path : String,
  topic : String,
  log_time_ns : UInt64,
) -> Unit {
  let out = Buffer()
  out.write_bytes(b"\x89MCAP0\r\n")
  let header = Buffer()
  write_test_string(header, "ros2")
  write_test_string(header, "")
  write_test_record(out, 0x01, header.to_bytes())
  let schema = Buffer()
  write_test_u16_le(schema, 1U)
  write_test_string(schema, "std_msgs/msg/String")
  write_test_string(schema, "ros2msg")
  schema.write_uint_le(0U)
  write_test_record(out, 0x03, schema.to_bytes())
  let channel = Buffer()
  write_test_u16_le(channel, 1U)
  write_test_u16_le(channel, 1U)
  write_test_string(channel, topic)
  write_test_string(channel, "cdr")
  channel.write_uint_le(0U)
  write_test_record(out, 0x04, channel.to_bytes())
  let message = Buffer()
  write_test_u16_le(message, 1U)
  message.write_uint_le(0U)
  message.write_uint64_le(log_time_ns)
  message.write_uint64_le(log_time_ns)
  message.write_bytes(b"\x00\x01\x00\x00")
  write_test_record(out, 0x05, message.to_bytes())
  write_test_record(out, 0x0F, b"\x00\x00\x00\x00")
  @fs.write_binary(path, out.to_bytes())
}

///|
fn test_metadata(relative_file_paths : Array[String]) -> String {
  let lines = [
    "rosbag2_bagfile_information:", "  version: 9", "  storage_identifier: mcap",
    "  compression_mode: \"\"", "  relative_file_paths:",
  ]
  for path in relative_file_paths {
    lines.push("    - " + path)
  }
  lines.push("  files:")
  lines.push("    - path: " + relative_file_paths[0])
  lines.join("\n") + "\n"
}

///|
async fn cleanup_test_bag(directory : String) -> Unit nocancel {
  for name in ["part_0.mcap", "part_1.mcap", "single.mcap", "metadata.yaml"] {
    @fs.remove(join_bag_path(directory, name), allow_missing=true)
  }
  @fs.remove(directory, allow_missing=true)
}

///|
test "bag metadata reads storage identifier and playback order" {
  let metadata = parse_bag_metadata(
    "rosbag2_bagfile_information:\n" +
    "  version: 9\n" +
    "  storage_identifier: mcap\n" +
    "  compression_mode: \"\"\n" +
    "  relative_file_paths:\n" +
    "    - part_0.mcap\n" +
    "    - 'part_1.mcap'\n" +
    "  files:\n" +
    "    - path: part_0.mcap\n",
  ).unwrap()
  assert_eq(metadata.storage_identifier, "mcap")
  assert_eq(metadata.compression_mode, "")
  assert_eq(metadata.relative_file_paths, ["part_0.mcap", "part_1.mcap"])
}

///|
async test "scan bag follows metadata order across MCAP files" {
  let directory = @fs.tmpdir(prefix="ros2-mbt-bag")
  defer cleanup_test_bag(directory)
  let first_path = join_bag_path(directory, "part_1.mcap")
  let second_path = join_bag_path(directory, "part_0.mcap")
  write_test_mcap(first_path, "/first", 1_000_000_000UL)
  write_test_mcap(second_path, "/second", 2_000_000_000UL)
  @fs.write_text(
    join_bag_path(directory, "metadata.yaml"),
    test_metadata(["part_1.mcap", "part_0.mcap"]),
  )
  let recording = scan_bag(directory).unwrap()
  assert_eq(recording.topics().map(fn(topic) { topic.name() }), [
    "/first", "/second",
  ])
  let published : Array[String] = []
  let sleeps : Array[Int32] = []
  let message_count = play(
    recording,
    [],
    1000U,
    fn() { 0L },
    fn(duration_ms) { sleeps.push(duration_ms) },
    fn(topic, _) {
      published.push(topic)
      Ok(())
    },
  ).unwrap()
  assert_eq(message_count, 2UL)
  assert_eq(published, ["/first", "/second"])
  assert_eq(sleeps, [1000])
}

///|
async test "scan bag accepts a single MCAP file" {
  let directory = @fs.tmpdir(prefix="ros2-mbt-bag")
  defer cleanup_test_bag(directory)
  let path = join_bag_path(directory, "single.mcap")
  write_test_mcap(path, "/chatter", 1_000_000_000UL)
  let recording = scan_bag(path).unwrap()
  assert_eq(recording.topics().map(fn(topic) { topic.name() }), ["/chatter"])
}

///|
async test "scan bag rejects a directory without metadata" {
  let directory = @fs.tmpdir(prefix="ros2-mbt-bag")
  defer cleanup_test_bag(directory)
  match scan_bag(directory) {
    Ok(_) => fail("expected a missing metadata.yaml error")
    Err(message) => assert_true(message.contains("metadata.yaml"))
  }
}
