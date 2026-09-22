///|
struct HzStats {
  mut samples : Int
  intervals : Array[Int64]
}

///|
fn add_sample(
  stats : HzStats,
  previous_sample_ms : Int64?,
  now_ms : Int64,
) -> Int64 {
  match previous_sample_ms {
    None => ()
    Some(previous) => stats.intervals.push(now_ms - previous)
  }
  stats.samples += 1
  now_ms
}

///|
fn print_hz_stats(stats : HzStats, duration_ms : Int) -> Unit {
  if stats.samples < 2 || stats.intervals.length() == 0 {
    println("average rate: 0.0")
    println("samples: " + stats.samples.to_string())
    return
  }
  let mut total_interval_ms = 0L
  let mut min_interval_ms = stats.intervals[0]
  let mut max_interval_ms = stats.intervals[0]
  for interval in stats.intervals {
    total_interval_ms += interval
    if interval < min_interval_ms {
      min_interval_ms = interval
    }
    if interval > max_interval_ms {
      max_interval_ms = interval
    }
  }
  let elapsed_ms = if total_interval_ms > 0L {
    total_interval_ms
  } else {
    duration_ms.to_int64()
  }
  let average = stats.intervals.length().to_int64().to_double() /
    elapsed_ms.to_double() *
    1000.0
  println("average rate: " + average.to_string())
  println("min: " + (1000.0 / max_interval_ms.to_double()).to_string())
  println("max: " + (1000.0 / min_interval_ms.to_double()).to_string())
  println("samples: " + stats.samples.to_string())
}

///|
async fn measure_best_effort(
  subscription : @transport.RosSubscription,
  duration_ms : Int,
) -> Result[Unit, String] {
  let deadline = @async.now() + duration_ms.to_int64()
  let stats = { samples: 0, intervals: [], }
  let mut previous_sample_ms : Int64? = None
  while true {
    let remaining_ms = (deadline - @async.now()).to_int()
    if remaining_ms <= 0 {
      break
    }
    let timeout_ms = if remaining_ms < CLI_DISCOVERY_POLL_MS {
      remaining_ms
    } else {
      CLI_DISCOVERY_POLL_MS
    }
    match
      @async.with_timeout_opt(timeout_ms, async fn() { subscription.receive() }) {
      None => ()
      Some(Ok(_)) =>
        previous_sample_ms = Some(
          add_sample(stats, previous_sample_ms, @async.now()),
        )
      Some(Err(message)) => {
        subscription.close()
        return Err(message)
      }
    }
  }
  subscription.close()
  print_hz_stats(stats, duration_ms)
  Ok(())
}

///|
async fn measure_reliable(
  subscription : @transport.ReliableRosSubscription,
  duration_ms : Int,
) -> Result[Unit, String] {
  let deadline = @async.now() + duration_ms.to_int64()
  let stats = { samples: 0, intervals: [], }
  let mut previous_sample_ms : Int64? = None
  while true {
    let remaining_ms = (deadline - @async.now()).to_int()
    if remaining_ms <= 0 {
      break
    }
    let timeout_ms = if remaining_ms < CLI_DISCOVERY_POLL_MS {
      remaining_ms
    } else {
      CLI_DISCOVERY_POLL_MS
    }
    match
      @async.with_timeout_opt(timeout_ms, async fn() { subscription.receive() }) {
      None => ()
      Some(Ok(_)) =>
        previous_sample_ms = Some(
          add_sample(stats, previous_sample_ms, @async.now()),
        )
      Some(Err(message)) => {
        subscription.close()
        return Err(message)
      }
    }
  }
  subscription.close()
  print_hz_stats(stats, duration_ms)
  Ok(())
}

///|
async fn run_topic_hz(
  topic_name : String,
  spin_time_ms : Int,
  duration_ms : Int,
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
      ignore(cli.participant.announce_spdp_forever(CLI_DISCOVERY_INTERVAL_MS))
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
      let is_reliable = match publication.qos() {
        Ok(qos) => qos.reliability() == @rtps.RELIABILITY_RELIABLE
        Err(message) => {
          cli.participant.close()
          return Err(message)
        }
      }
      let (discovery, user_socket) = cli.participant.into_parts()
      discovery.close()
      let reader_id = match @rtps.EntityId::new(b"hz1", 0x04) {
        Ok(value) => value
        Err(message) => {
          user_socket.close()
          return Err(message)
        }
      }
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
