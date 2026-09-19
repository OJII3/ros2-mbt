///|
async test "UDP binds an ephemeral loopback port" {
  let socket = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let address = socket.local_addr()
  assert_eq(address.ip(), 0x7F000001U)
  assert_true(address.port() > 0)
  socket.close()
}

///|
async test "UDP sends and receives one datagram" {
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  sender.send_to(b"RTPS", receiver.local_addr())
  let (payload, source) = receiver.receive()
  assert_eq(payload, b"RTPS")
  assert_eq(source.ip(), 0x7F000001U)
  sender.close()
  receiver.close()
}

///|
async test "UDP sends and receives one RTPS message" {
  let prefix = match
    @rtps.GuidPrefix::from_array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let header = @rtps.Header::new(prefix, @rtps.VendorId::new(1, 15))
  let message = @rtps.Message::new(header)
  message.add(@rtps.Submessage::new(@rtps.SubmessageId::Data, 0x05, b"payload"))
  let receiver = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  let sender = Udp::bind(@socket.Addr::new(0x7F000001U, 0))
  match sender.send_message(message, receiver.local_addr()) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let (decoded, source) = match receiver.receive_message() {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(decoded, message)
  assert_eq(source.ip(), 0x7F000001U)
  sender.close()
  receiver.close()
}
