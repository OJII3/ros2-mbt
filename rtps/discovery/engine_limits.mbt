///|
/// Fixed discovery receive bounds shared by SPDP and SEDP, including writers
/// not yet announced by SPDP. Admission rejects new work without marking its
/// sequence received, so reliable retransmission can succeed after capacity frees.
const DISCOVERY_MAX_RECEIVE_WRITERS : Int32 = 128

///|
const DISCOVERY_MAX_SAMPLE_BYTES : UInt32 = 1024U * 1024U

///|
const DISCOVERY_MAX_FRAGMENTS : Int32 = 4096

///|
const DISCOVERY_MAX_INCOMPLETE_SAMPLES : Int32 = 16

///|
/// Payload bytes plus eight bytes per fragment-presence slot, across the engine.
const DISCOVERY_MAX_FRAGMENT_BYTES : Int32 = 4 * 1024 * 1024

///|
fn DiscoveryEngine::can_add_discovery_reader(self : DiscoveryEngine) -> Bool {
  self.sedp_readers.length() + self.spdp_fragment_readers.length() <
  DISCOVERY_MAX_RECEIVE_WRITERS
}

///|
fn DiscoveryEngine::fragment_receive_usage(
  self : DiscoveryEngine,
) -> (Int32, Int32) {
  let mut count = 0
  let mut bytes = 0
  for readers in [self.sedp_readers, self.spdp_fragment_readers] {
    for remote in readers {
      let (reader_count, reader_bytes) = remote.reader.fragment_receive_usage()
      count += reader_count
      bytes += reader_bytes
    }
  }
  (count, bytes)
}

///|
fn DiscoveryEngine::can_receive_discovery_fragment(
  self : DiscoveryEngine,
  prefix : @core.GuidPrefix,
  fragment : @core.DataFragSubmessage,
) -> Bool {
  if fragment.sample_size() > DISCOVERY_MAX_SAMPLE_BYTES {
    return false
  }
  let size = fragment.sample_size().reinterpret_as_int()
  let fragment_size = fragment.fragment_size().to_int()
  let fragments = (size + fragment_size - 1) / fragment_size
  if fragments > DISCOVERY_MAX_FRAGMENTS {
    return false
  }
  for readers in [self.sedp_readers, self.spdp_fragment_readers] {
    for remote in readers {
      if remote.writer_prefix == prefix &&
        remote.writer_id == fragment.writer_id() {
        if remote.reader.has_received_sequence(
            fragment.writer_sequence_number(),
          ) ||
          remote.reader.has_incomplete_fragment(
            fragment.writer_sequence_number(),
          ) {
          return true
        }
      }
    }
  }
  let (count, bytes) = self.fragment_receive_usage()
  count < DISCOVERY_MAX_INCOMPLETE_SAMPLES &&
  bytes + size + fragments * 8 <= DISCOVERY_MAX_FRAGMENT_BYTES
}

///|
/// Fixed lifetime, not extended by incoming fragments: unknown writers cannot
/// retain global assembly slots forever by trickling packets. SPDP is periodic
/// best effort; expired assemblies and duplicate tracking can safely be retried.
const DISCOVERY_SPDP_FRAGMENT_LIFETIME_MS : Int64 = 5000L
