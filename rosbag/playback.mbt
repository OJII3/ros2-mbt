///|
/// Calculate a message's absolute playback offset in milliseconds.
/// `rate_milli` stores the playback multiplier in thousandths.
pub fn playback_target_ms(
  log_time_ns : UInt64,
  first_log_time_ns : UInt64,
  rate_milli : UInt32,
) -> Result[Int64, String] {
  if rate_milli == 0U {
    return Err("playback rate must be positive")
  }
  let delta_ns = if log_time_ns > first_log_time_ns {
    log_time_ns - first_log_time_ns
  } else {
    0UL
  }
  let delta_ms = delta_ns / 1_000_000UL
  let target_ms = delta_ms * 1000UL / rate_milli.to_uint64()
  if target_ms > 0x7FFFFFFFFFFFFFFFUL {
    return Err("playback delay exceeds the supported range")
  }
  Ok(target_ms.reinterpret_as_int64())
}

///|
/// Replay a recording using injected clock, sleep, and publisher functions.
///
/// MCAP files are played in recording order on one timeline. File order is
/// preserved. Messages with decreasing timestamps are sent immediately once
/// their target time has passed.
pub async fn play(
  recording : BagRecording,
  requested_topics : Array[String],
  rate_milli : UInt32,
  now_ms : () -> Int64,
  sleep_ms : async (Int32) -> Unit,
  publish : async (String, Bytes) -> Result[Unit, String],
) -> Result[UInt64, String] {
  if rate_milli == 0U {
    return Err("playback rate must be positive")
  }
  let first_log_time_ns = match recording.first_log_time_ns {
    Some(value) => value
    None => return Ok(0UL)
  }
  let start_ms = now_ms()
  let mut published = 0UL
  for file in recording.files {
    let file_messages = match
      play_bag_file(
        file, requested_topics, rate_milli, first_log_time_ns, start_ms, now_ms,
        sleep_ms, publish,
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    published += file_messages
  }
  Ok(published)
}

///|
async fn play_bag_file(
  file : BagRecordingFile,
  requested_topics : Array[String],
  rate_milli : UInt32,
  first_log_time_ns : UInt64,
  start_ms : Int64,
  now_ms : () -> Int64,
  sleep_ms : async (Int32) -> Unit,
  publish : async (String, Bytes) -> Result[Unit, String],
) -> Result[UInt64, String] {
  let handle = @fs.open(file.path, mode=ReadOnly) catch {
    _ => return Err("could not reopen MCAP file for playback: " + file.path)
  }
  defer handle.close()
  let reader = match @mcap.Reader::new(handle) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let source = match McapMessageSource::new(reader, file.catalog) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  play_source(
    source, requested_topics, rate_milli, first_log_time_ns, start_ms, now_ms, sleep_ms,
    publish,
  )
}

///|
async fn play_source(
  source : McapMessageSource,
  requested_topics : Array[String],
  rate_milli : UInt32,
  first_log_time_ns : UInt64,
  start_ms : Int64,
  now_ms : () -> Int64,
  sleep_ms : async (Int32) -> Unit,
  publish : async (String, Bytes) -> Result[Unit, String],
) -> Result[UInt64, String] {
  let mut published = 0UL
  while true {
    let message = match source.next() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    match message {
      None => return Ok(published)
      Some(message) => {
        if requested_topics.length() > 0 &&
          !requested_topics.contains(message.topic_name) {
          continue
        }
        let target_ms = match
          playback_target_ms(message.log_time_ns, first_log_time_ns, rate_milli) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        let elapsed_ms = now_ms() - start_ms
        let delay_ms = target_ms - elapsed_ms
        if delay_ms > 0L {
          if delay_ms > 0x7FFFFFFFL {
            return Err("playback wait exceeds the supported range")
          }
          sleep_ms(delay_ms.to_int())
        }
        match publish(message.topic_name, message.payload) {
          Ok(_) => published += 1UL
          Err(error) => return Err("failed to publish bag message: " + error)
        }
      }
    }
  } nobreak {
    Err("bag playback stopped unexpectedly")
  }
}

///|
/// Run a playback pass once or repeat it until it fails.
/// A loop that publishes no messages is rejected to prevent a busy loop.
pub async fn play_repeatedly(
  loop_enabled : Bool,
  play_pass : async () -> Result[UInt64, String],
) -> Result[UInt64, String] {
  while true {
    let message_count = match play_pass() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    if !loop_enabled {
      return Ok(message_count)
    }
    if message_count == 0UL {
      return Err("cannot loop a bag pass with no messages")
    }
  } nobreak {
    Err("bag playback loop stopped unexpectedly")
  }
}
