///|
fn print_hz_stats(stats : HzStats, duration_ms : Int32) -> Unit {
  match summarize_hz_stats(stats, duration_ms) {
    None => println("average rate: 0.0")
    Some(summary) => {
      println("average rate: " + summary.average.to_string())
      println("min: " + summary.min.to_string())
      println("max: " + summary.max.to_string())
    }
  }
  println("samples: " + stats.samples.to_string())
}

///|
// The receiver reports whether a sample arrived within the requested timeout.
// Clock and receive effects are supplied by the transport adapters.
async fn collect_hz_stats(
  duration_ms : Int32,
  now_ms : () -> Int64,
  receive_sample : async (Int32) -> Result[Bool, String],
) -> Result[HzStats, String] {
  let deadline = now_ms() + duration_ms.to_int64()
  let stats = { samples: 0, intervals: [], }
  let mut previous_sample_ms : Int64? = None
  while true {
    let remaining_ms = (deadline - now_ms()).to_int()
    if remaining_ms <= 0 {
      return Ok(stats)
    }
    let timeout_ms = if remaining_ms < CLI_DISCOVERY_POLL_MS {
      remaining_ms
    } else {
      CLI_DISCOVERY_POLL_MS
    }
    match receive_sample(timeout_ms) {
      Ok(false) => ()
      Ok(true) =>
        previous_sample_ms = Some(
          add_sample(stats, previous_sample_ms, now_ms()),
        )
      Err(message) => return Err(message)
    }
  } nobreak {
    Err("measurement loop stopped")
  }
}

///|
async fn measure_best_effort(
  subscription : @transport.RosSubscription,
  duration_ms : Int32,
) -> Result[Unit, String] {
  defer subscription.close()
  let stats = match
    collect_hz_stats(duration_ms, fn() { @async.now() }, async fn(timeout_ms) {
      match
        @async.with_timeout_opt(timeout_ms, async fn() {
          subscription.receive()
        }) {
        None => Ok(false)
        Some(Ok(_)) => Ok(true)
        Some(Err(message)) => Err(message)
      }
    }) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  print_hz_stats(stats, duration_ms)
  Ok(())
}

///|
async fn measure_reliable(
  subscription : @transport.ReliableRosSubscription,
  duration_ms : Int32,
) -> Result[Unit, String] {
  defer subscription.close()
  let stats = match
    collect_hz_stats(duration_ms, fn() { @async.now() }, async fn(timeout_ms) {
      match
        @async.with_timeout_opt(timeout_ms, async fn() {
          subscription.receive()
        }) {
        None => Ok(false)
        Some(Ok(_)) => Ok(true)
        Some(Err(message)) => Err(message)
      }
    }) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  print_hz_stats(stats, duration_ms)
  Ok(())
}

///|
async fn run_topic_hz(
  topic_name : String,
  spin_time_ms : Int32,
  duration_ms : Int32,
) -> Result[Unit, String] {
  let ros_name = match normalize_ros_topic_name(topic_name) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if duration_ms <= 0 {
    return Err("the measurement duration must be positive")
  }
  let cli = match new_cli_participant(false) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let publication_result = @async.with_task_group() <| group => {
    group.spawn_bg(no_wait=true) <| () => {
      match cli.participant.announce_spdp_forever(CLI_DISCOVERY_INTERVAL_MS) {
        Ok(_) => ()
        Err(message) =>
          println("error: discovery announcement failed: " + message)
      }
    }
    match spin_discovery(cli.participant, spin_time_ms, false) {
      Ok(_) => find_publication(cli.participant, ros_name)
      Err(message) => Err(message)
    }
  }
  match publication_result {
    Err(message) => {
      cli.participant.close()
      Err(message)
    }
    Ok(publication) => {
      let topic = match
        @ros.RosTopic::from_dds(
          ros_name,
          publication.topic_name(),
          publication.type_name(),
        ) {
        Ok(value) => value
        Err(message) => {
          cli.participant.close()
          return Err(message)
        }
      }
      let publisher_qos = match publication.qos() {
        Ok(qos) => qos
        Err(message) => {
          cli.participant.close()
          return Err(message)
        }
      }
      let reader_id = match @rtps.EntityId::new(b"hz1", 0x04) {
        Ok(value) => value
        Err(message) => {
          cli.participant.close()
          return Err(message)
        }
      }
      let requested_qos = @rtps.SedpQos::new(
        publisher_qos.reliability(),
        publisher_qos.durability(),
        publisher_qos.history(),
        publisher_qos.depth(),
      )
      match
        cli.participant.register_topic_endpoint(
          topic,
          Subscription,
          reader_id,
          requested_qos,
        ) {
        Ok(_) => ()
        Err(message) => {
          cli.participant.close()
          return Err(message)
        }
      }
      let (discovery, user_socket) = cli.participant.into_parts()
      discovery.close()
      let is_reliable = publisher_qos.reliability() ==
        @rtps.RELIABILITY_RELIABLE
      if is_reliable {
        let subscription = match
          @transport.ReliableRosSubscription::new_for_publication(
            topic,
            user_socket,
            cli.prefix,
            cli.vendor_id,
            reader_id,
            publication,
          ) {
          Ok(value) => value
          Err(message) => {
            user_socket.close()
            return Err(message)
          }
        }
        measure_reliable(subscription, duration_ms)
      } else {
        let subscription = match
          @transport.RosSubscription::new_for_publication_with_prefix(
            topic,
            user_socket,
            cli.prefix,
            reader_id,
            publication,
          ) {
          Ok(value) => value
          Err(message) => {
            user_socket.close()
            return Err(message)
          }
        }
        measure_best_effort(subscription, duration_ms)
      }
    }
  }
}
