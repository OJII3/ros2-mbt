///|
test "bench CDR reader scalar fields" (b : @bench.T) {
  let writer = @cdr.Writer::with_capacity(32 * 96)
  for i in 0..<32 {
    writer.write_u32(i.reinterpret_as_uint())
    writer.write_i32(-i)
    writer.write_f64(i.to_double())
  }
  let payload = writer.to_bytes()
  b.bench(fn() {
    let reader = @cdr.Reader::from_bytes(payload).unwrap()
    let mut total = 0L
    for _ in 0..<32 {
      total += reader.read_u32().unwrap().reinterpret_as_int().to_int64()
      total += reader.read_i32().unwrap().to_int64()
      total += reader.read_f64().unwrap().to_int64()
    }
    b.keep(total)
  })
}

///|
test "bench CDR writer scalar fields" (b : @bench.T) {
  b.bench(fn() {
    let writer = @cdr.Writer::with_capacity(32 * 96)
    for i in 0..<32 {
      writer.write_u32(i.reinterpret_as_uint())
      writer.write_i32(-i)
      writer.write_f64(i.to_double())
    }
    b.keep(writer)
  })
}

///|
test "bench CDR reader 1 MiB byte sequence" (b : @bench.T) {
  let payload_bytes = Bytes::from_array(Array::make(1024 * 1024, b'\x5A'))
  let writer = @cdr.Writer::new()
  writer.write_byte_sequence(payload_bytes)
  let payload = writer.to_bytes()
  b.bench(fn() {
    let reader = @cdr.Reader::from_bytes(payload).unwrap()
    b.keep(reader.read_byte_sequence().unwrap())
  })
}

///|
test "bench CDR writer 1 MiB byte sequence" (b : @bench.T) {
  let payload_bytes = Bytes::from_array(Array::make(1024 * 1024, b'\x5A'))
  b.bench(fn() {
    let writer = @cdr.Writer::with_capacity(1024 * 1024 + 8)
    writer.write_byte_sequence(payload_bytes)
    b.keep(writer)
  })
}

///|
test "bench CDR reader 1080 f64 array" (b : @bench.T) {
  let values = Array::make(1080, 1.5)
  let writer = @cdr.Writer::with_capacity(1080 * 8 + 8)
  writer.write_f64_array(values)
  let payload = writer.to_bytes()
  b.bench(fn() {
    let reader = @cdr.Reader::from_bytes(payload).unwrap()
    b.keep(reader.read_f64_array(1080).unwrap())
  })
}

///|
test "bench CDR writer 1080 f64 array" (b : @bench.T) {
  let values = Array::make(1080, 1.5)
  b.bench(fn() {
    let writer = @cdr.Writer::with_capacity(1080 * 8 + 8)
    writer.write_f64_array(values)
    b.keep(writer)
  })
}
