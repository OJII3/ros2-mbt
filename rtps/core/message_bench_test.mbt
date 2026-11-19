///|
fn bench_guid_prefix() -> @core.GuidPrefix {
  @core.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]).unwrap()
}

///|
fn bench_entity_id(kind : Byte) -> @core.EntityId {
  @core.EntityId::new(b"\x00\x01\x00", kind).unwrap()
}

///|
fn bench_cdr_payload() -> Bytes {
  let writer = @cdr.Writer::new()
  writer.write_bool(true)
  writer.write_u8(7)
  writer.write_i16(1234)
  writer.write_u16_uint(4321U)
  writer.write_i32(-12345678)
  writer.write_u32(3456789012U)
  writer.write_i64(-123456789012345L)
  writer.write_u64(123456789012345UL)
  writer.write_f32(1.5F)
  writer.write_f64(2.5)
  writer.write_string("benchmark payload")
  writer.to_bytes()
}

///|
fn bench_data_message(payload : Bytes) -> @core.Message {
  let data = @core.DataSubmessage::new(
    bench_entity_id(0x04),
    bench_entity_id(0x03),
    1L,
    payload,
  )
  let message = @core.Message::new(
    @core.Header::new(bench_guid_prefix(), @core.VendorId::new(1, 15)),
  )
  message.add(data.to_submessage())
  message
}

///|
test "bench RTPS message 84 B serialize" (b : @bench.T) {
  let message = bench_data_message(bench_cdr_payload())
  b.bench(fn() { b.keep(message.to_bytes().unwrap()) })
}

///|
test "bench RTPS message 84 B parse" (b : @bench.T) {
  let encoded = bench_data_message(bench_cdr_payload()).to_bytes().unwrap()
  b.bench(fn() {
    let message = @core.Message::from_bytes(encoded).unwrap()
    b.keep(message.submessages().length())
  })
}

///|
test "bench RTPS message 1 KiB serialize" (b : @bench.T) {
  let payload = Bytes::from_array(Array::make(1024, b'\x2A'))
  let message = bench_data_message(payload)
  b.bench(fn() { b.keep(message.to_bytes().unwrap()) })
}

///|
test "bench RTPS message 1 KiB parse" (b : @bench.T) {
  let payload = Bytes::from_array(Array::make(1024, b'\x2A'))
  let encoded = bench_data_message(payload).to_bytes().unwrap()
  b.bench(fn() {
    let message = @core.Message::from_bytes(encoded).unwrap()
    b.keep(message.submessages().length())
  })
}

///|
fn bench_data_frag_message(payload : Bytes) -> @core.Message {
  let fragment = @core.DataFragSubmessage::new(
    bench_entity_id(0x04),
    bench_entity_id(0x03),
    1L,
    1U,
    1,
    1200,
    payload.length().reinterpret_as_uint(),
    payload,
  ).unwrap()
  let message = @core.Message::new(
    @core.Header::new(bench_guid_prefix(), @core.VendorId::new(1, 15)),
  )
  message.add(fragment.to_submessage())
  message
}

///|
test "bench RTPS DATA_FRAG 1200 B serialize" (b : @bench.T) {
  let payload = Bytes::from_array(Array::make(1200, b'\x2A'))
  let message = bench_data_frag_message(payload)
  b.bench(fn() { b.keep(message.to_bytes().unwrap()) })
}

///|
test "bench RTPS DATA_FRAG 1200 B parse" (b : @bench.T) {
  let payload = Bytes::from_array(Array::make(1200, b'\x2A'))
  let encoded = bench_data_frag_message(payload).to_bytes().unwrap()
  b.bench(fn() {
    let message = @core.Message::from_bytes(encoded).unwrap()
    b.keep(message.submessages().length())
  })
}
