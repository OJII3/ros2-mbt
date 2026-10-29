///|
test "best effort fragment completions keep bounded sample history" {
  let reader_id = EntityId::unknown()
  let writer_id = EntityId::new(b"abc", 0xC2).unwrap()
  let reader = ReliableDataReader::new(reader_id, writer_id)
  for sequence in 1..<=4096 {
    for number in 1..<=2 {
      let fragment = DataFragSubmessage::new(
        reader_id,
        writer_id,
        sequence.to_int64(),
        number.reinterpret_as_uint(),
        (1 : Int32).to_uint16(),
        (1 : Int32).to_uint16(),
        2U,
        b"a",
      ).unwrap()
      let result = reader.accept_best_effort_fragment(fragment).unwrap()
      assert_eq(result is Some(_), number == 2)
      assert_true(reader.samples.length() <= 256)
      assert_true(reader.fragments.length() <= 1)
      assert_eq(reader.gaps.length(), 0)
    }
  }
  assert_eq(reader.fragments.length(), 0)
  assert_eq(reader.samples.length(), 256)
  assert_eq(reader.next_acknack_count(), 1U)
  assert_eq(reader.next_nackfrag_count(), 1U)
}
