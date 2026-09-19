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
