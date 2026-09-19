///|
/// A reliable writer for one SEDP publication or subscription announcement.
///
/// The caller still drives ACKNACK receive scheduling, while this wrapper
/// owns endpoint serialization and the reliable DATA/HEARTBEAT sequence.
pub struct ReliableSedpWriter {
  endpoint : @rtps.SedpEndpointData
  writer : ReliableDataWriter
}

///|
/// Create a reliable SEDP writer targeting a discovered participant.
pub fn ReliableSedpWriter::new(
  socket : Udp,
  vendor_id : @rtps.VendorId,
  endpoint : @rtps.SedpEndpointData,
  remote_participant : @rtps.SpdpParticipantData,
  first_sequence_number : Int64,
) -> Result[ReliableSedpWriter, String] {
  let writer = match
    ReliableDataWriter::new_for_sedp(
      socket, vendor_id, endpoint, remote_participant, first_sequence_number,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ endpoint, writer, })
}

///|
/// Return the endpoint carried by this reliable SEDP writer.
pub fn ReliableSedpWriter::endpoint(
  self : ReliableSedpWriter,
) -> @rtps.SedpEndpointData {
  self.endpoint
}

///|
/// Return the sequence number that will be used by the next announcement.
pub fn ReliableSedpWriter::next_sequence_number(
  self : ReliableSedpWriter,
) -> Int64 {
  self.writer.next_sequence_number()
}

///|
/// Return the number of announcements retained for retransmission.
pub fn ReliableSedpWriter::history_length(self : ReliableSedpWriter) -> Int {
  self.writer.history_length()
}

///|
/// Serialize and announce the endpoint, then send its HEARTBEAT.
pub async fn ReliableSedpWriter::announce_once(
  self : ReliableSedpWriter,
) -> Result[Unit, String] {
  let payload = match
    self.endpoint.to_cdr_bytes_with_vendor(self.writer.vendor_id()) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match self.writer.write(payload) {
    Ok(_) => self.writer.send_heartbeat()
    Err(message) => Err(message)
  }
}

///|
/// Receive a matching ACKNACK and retransmit any requested history samples.
pub async fn ReliableSedpWriter::receive_acknack(
  self : ReliableSedpWriter,
) -> Result[(@rtps.AckNackSubmessage, @socket.Addr), String] {
  self.writer.receive_acknack()
}

///|
/// Apply an ACKNACK directly and retransmit any requested history samples.
pub async fn ReliableSedpWriter::handle_acknack(
  self : ReliableSedpWriter,
  acknack : @rtps.AckNackSubmessage,
) -> Result[Unit, String] {
  self.writer.handle_acknack(acknack)
}

///|
/// Close the SEDP writer's underlying UDP socket.
pub fn ReliableSedpWriter::close(self : ReliableSedpWriter) -> Unit {
  self.writer.close()
}
