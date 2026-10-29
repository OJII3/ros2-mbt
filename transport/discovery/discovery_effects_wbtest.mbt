///|
fn effects_test_participant(id : Byte) -> @rtps.SpdpParticipantData {
  @rtps.SpdpParticipantData::new(
    @rtps.Guid::new(
      @rtps.GuidPrefix::from_array([id, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]).unwrap(),
      @rtps.EntityId::new(b"prt", 0xC1).unwrap(),
    ),
    @rtps.VendorId::new(1, 15),
    0,
    60,
    0U,
    3U,
  )
}

///|
async test "discovery commits only accepted sends and retries the same sequence" {
  let socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer socket.close()
  let receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer receiver.close()
  let session = DiscoverySession::new_default(
    socket,
    effects_test_participant(0),
    0U,
    1L,
  ).unwrap()
  let first = session.engine.announce_spdp(false).unwrap()[0]
  let second = session.engine.announce_spdp(false).unwrap()[0]
  let good = discovery_addr_to_locator(receiver.local_addr())
  session.enqueue_outgoing([{ message: first.message, destination: good, }])
  session.flush_outgoing().unwrap()
  let (message, _) = @async.with_timeout(1000, async fn() {
    receiver.receive_message().unwrap()
  })
  assert_eq(
    @rtps.DataSubmessage::from_submessage(message.submessages()[0])
    .unwrap()
    .writer_sequence_number(),
    1L,
  )
  session.enqueue_outgoing([{ message: second.message, destination: good, }])
  let closed = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  closed.close()
  assert_true(session.flush_outgoing_on(closed) is Err(_))
  assert_eq(session.outgoing.length(), 1)
  // A retry changes only delivery, never protocol production or sequence state.
  session.flush_outgoing().unwrap()
  let (message, _) = @async.with_timeout(1000, async fn() {
    receiver.receive_message().unwrap()
  })
  assert_eq(
    @rtps.DataSubmessage::from_submessage(message.submessages()[0])
    .unwrap()
    .writer_sequence_number(),
    1L,
  )
  assert_eq(session.engine.next_sequence_number(), 2L)
  assert_eq(session.outgoing.length(), 0)
}

///|
async test "a failed heartbeat response does not discard later discovery events" {
  let socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  let input = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer input.close()
  let session = DiscoverySession::new_with_receive_sockets(
    socket,
    [input],
    effects_test_participant(0),
    @rtps.EntityId::unknown(),
    @rtps.EntityId::unknown(),
    input.local_addr(),
    1L,
  ).unwrap()
  defer session.close()
  let remote = effects_test_participant(1)
  let kind = @rtps.SedpEndpointKind::Publication
  let message = @rtps.Message::new(
    @rtps.Header::new(remote.participant_guid().prefix(), remote.vendor_id()),
  )
  message.add(
    @rtps.HeartbeatSubmessage::new(
      kind.builtin_reader_id(),
      kind.builtin_writer_id(),
      1L,
      2L,
      1U,
    )
    .unwrap()
    .to_submessage(),
  )
  for sequence in 1..<3 {
    let endpoint = @rtps.SedpEndpointData::new(
      Publication,
      @rtps.Guid::new(
        remote.participant_guid().prefix(),
        @rtps.EntityId::new(Bytes::from_array([sequence.to_byte(), 0, 0]), 0x02).unwrap(),
      ),
      "rt/chatter",
      "std_msgs::msg::dds_::String_",
    ).unwrap()
    message.add(
      endpoint
      .to_data_submessage(
        kind.builtin_reader_id(),
        kind.builtin_writer_id(),
        sequence.to_int64(),
      )
      .unwrap()
      .to_submessage(),
    )
  }
  // Feed one whole packet before attempting its effects, as the socket adapter does.
  let effects = session.engine
    .receive(message, discovery_addr_to_locator(input.local_addr()), 0L)
    .unwrap()
  assert_eq(effects.events.length(), 2)
  session.enqueue_effects(effects, input.local_addr())
  socket.close()
  assert_true(session.flush_outgoing() is Err(_))
  assert_eq(session.outgoing.length(), 1)
  for _ in 0..<2 {
    let (event, source) = session.receive_once().unwrap()
    assert_true(event is Publication(_))
    assert_eq(source, input.local_addr())
  }
  assert_eq(session.pending_events.length(), 0)
  assert_eq(session.outgoing.length(), 1)
}

///|
async test "concurrent discovery flushes send each queued datagram once" {
  let socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  let receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer receiver.close()
  let session = DiscoverySession::new_default(
    socket,
    effects_test_participant(0),
    0U,
    1L,
  ).unwrap()
  defer session.close()
  for _ in 0..<20 {
    let output = session.engine.announce_spdp(false).unwrap()[0]
    session.enqueue_outgoing([
      {
        message: output.message,
        destination: discovery_addr_to_locator(receiver.local_addr()),
      },
    ])
  }
  @async.all([
    async fn() { session.flush_outgoing().unwrap() },
    async fn() { session.flush_outgoing().unwrap() },
  ])
  |> ignore
  for sequence in 1..<21 {
    let (message, _) = @async.with_timeout(1000, async fn() {
      receiver.receive_message().unwrap()
    })
    assert_eq(
      @rtps.DataSubmessage::from_submessage(message.submessages()[0])
      .unwrap()
      .writer_sequence_number(),
      sequence.to_int64(),
    )
  }
  assert_eq(session.outgoing.length(), 0)
}

///|
async test "permanently invalid destinations are retained separately without blocking unrelated sends" {
  let socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  let receiver = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer receiver.close()
  let session = DiscoverySession::new_default(
    socket,
    effects_test_participant(0),
    0U,
    1L,
  ).unwrap()
  defer session.close()
  let good = discovery_addr_to_locator(receiver.local_addr())
  let ipv6 = @rtps.Locator::new(
    @rtps.LOCATOR_KIND_UDP_V6,
    7450U,
    Bytes::from_array(Array::make(16, 0)),
  ).unwrap()
  for
    destination in [
      ipv6,
      good,
      @rtps.Locator::udp_v4(b"\x7F\x00\x00\x01", 0U).unwrap(),
      good,
    ] {
    let output = session.engine.announce_spdp(false).unwrap()[0]
    session.enqueue_outgoing([{ message: output.message, destination, }])
  }
  assert_true(session.flush_outgoing() is Err(_))
  assert_eq(session.outgoing.length(), 0)
  for sequence in [2L, 4L] {
    let (message, _) = @async.with_timeout(1000, async fn() {
      receiver.receive_message().unwrap()
    })
    assert_eq(
      @rtps.DataSubmessage::from_submessage(message.submessages()[0])
      .unwrap()
      .writer_sequence_number(),
      sequence,
    )
  }
  // A permanent rejection reports once; it cannot poison subsequent flushes.
  session.flush_outgoing().unwrap()
  let rejected = session.take_rejected_outgoing()
  assert_eq(rejected.length(), 2)
  assert_eq(rejected[0].destination, ipv6)
  assert_eq(
    @rtps.DataSubmessage::from_submessage(rejected[0].message.submessages()[0])
    .unwrap()
    .writer_sequence_number(),
    1L,
  )
  assert_eq(session.take_rejected_outgoing().length(), 0)
}

///|
async test "SEDP announcement wakes a receive sleeping on a long participant lease and repairs initial loss" {
  let socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  let remote_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer remote_socket.close()
  let session = DiscoverySession::new_default(
    socket,
    effects_test_participant(0),
    0U,
    1L,
  ).unwrap()
  defer session.close()
  let service = DiscoveryService::new(session)
  let remote = effects_test_participant(1)
  remote.add_metatraffic_unicast(
    discovery_addr_to_locator(remote_socket.local_addr()),
  )
  // Seed through the engine's actual builtin IDs, independent of participant entity ID.
  let remote_message = remote
    .to_data_submessage(
      @rtps.EntityId::new(
        b"\x00\x01\x00",
        @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_READER,
      ).unwrap(),
      @rtps.EntityId::new(
        b"\x00\x01\x00",
        @rtps.ENTITYID_SPDP_BUILTIN_PARTICIPANT_WRITER,
      ).unwrap(),
      1L,
    )
    .to_message(remote.participant_guid().prefix(), remote.vendor_id())
  ignore(
    session.engine
    .receive(
      remote_message,
      discovery_addr_to_locator(remote_socket.local_addr()),
      session.clock.now_ms(),
    )
    .unwrap(),
  )
  let endpoint = @rtps.SedpEndpointData::new(
    Publication,
    @rtps.Guid::new(
      session.participant.participant_guid().prefix(),
      @rtps.EntityId::new(b"pub", 0x02).unwrap(),
    ),
    "rt/wake",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  @async.with_timeout(2000, async fn() {
    @async.with_task_group() <| group => {
      group.spawn_bg(no_wait=true) <| () => { ignore(session.receive_once()) }
      // Let receive register its socket wait and the 60-second lease timer.
      @async.sleep(20)
      service.announce_sedp_once(endpoint, remote).unwrap()
      let mut repaired = false
      while !repaired {
        let (message, _) = remote_socket.receive_message().unwrap()
        for submessage in message.submessages() {
          if submessage.id() != Heartbeat {
            continue
          }
          let heartbeat = @rtps.HeartbeatSubmessage::from_submessage(submessage).unwrap()
          // Drop the initial DATA and both immediate HEARTBEATs; no incoming traffic wakes the session.
          if heartbeat.count() <= 2U {
            continue
          }
          let kind = endpoint.kind()
          remote_socket
          .send_message(
            @rtps.AckNackSubmessage::new(
              kind.builtin_reader_id(),
              kind.builtin_writer_id(),
              1L,
              1U,
              [0x80000000U],
              1U,
            )
            .unwrap()
            .to_message(remote.participant_guid().prefix(), remote.vendor_id()),
            socket.local_addr(),
          )
          .unwrap()
          let (data, _) = remote_socket.receive_data().unwrap()
          assert_eq(data.writer_sequence_number(), 1L)
          repaired = true
        }
      }
    }
  })
}

///|
async test "a receive with no deadline wakes when a concurrent announcement starts reliability" {
  let socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  let remote_socket = @wire.Udp::bind(@socket.Addr::new(0x7F000001U, 0)).unwrap()
  defer remote_socket.close()
  let session = DiscoverySession::new_default(
    socket,
    effects_test_participant(0),
    0U,
    1L,
  ).unwrap()
  defer session.close()
  assert_eq(session.engine.next_deadline(), None)
  let service = DiscoveryService::new(session)
  let remote = effects_test_participant(1)
  remote.add_metatraffic_unicast(
    discovery_addr_to_locator(remote_socket.local_addr()),
  )
  let endpoint = @rtps.SedpEndpointData::new(
    Publication,
    @rtps.Guid::new(
      session.participant.participant_guid().prefix(),
      @rtps.EntityId::new(b"pub", 0x02).unwrap(),
    ),
    "rt/wake",
    "std_msgs::msg::dds_::String_",
  ).unwrap()
  @async.with_timeout(500, async fn() {
    @async.with_task_group() <| group => {
      let waiter = group.spawn(async fn() {
        session.receive_message_or_lease_expiry().unwrap()
      })
      @async.sleep(20)
      service.announce_sedp_once(endpoint, remote).unwrap()
      assert_true(waiter.wait() is DeadlineChanged)
    }
  })
}
