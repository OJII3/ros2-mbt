///| Serialize an RTPS SequenceNumber_t as high int32 followed by low uint32.
fn append_sequence_number_le(bytes : Array[Byte], value : Int64) -> Unit {
  let encoded = value.reinterpret_as_uint64()
  let high = encoded >> 32
  let low = encoded
  bytes.push(high.to_byte())
  bytes.push((high >> 8).to_byte())
  bytes.push((high >> 16).to_byte())
  bytes.push((high >> 24).to_byte())
  bytes.push(low.to_byte())
  bytes.push((low >> 8).to_byte())
  bytes.push((low >> 16).to_byte())
  bytes.push((low >> 24).to_byte())
}

///| Parse an RTPS SequenceNumber_t encoded as high int32 followed by low uint32.
fn read_sequence_number_le(input : Bytes, offset : Int) -> Int64 {
  let high = input[offset].to_int().to_uint64() |
    (input[offset + 1].to_int().to_uint64() << 8) |
    (input[offset + 2].to_int().to_uint64() << 16) |
    (input[offset + 3].to_int().to_uint64() << 24)
  let low = input[offset + 4].to_int().to_uint64() |
    (input[offset + 5].to_int().to_uint64() << 8) |
    (input[offset + 6].to_int().to_uint64() << 16) |
    (input[offset + 7].to_int().to_uint64() << 24)
  ((high << 32) | low).reinterpret_as_int64()
}
