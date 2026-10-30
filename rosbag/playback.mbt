///|
/// Return catalog topics selected by name, or all topics when the list is empty.
pub fn BagCatalog::select_topics(
  self : BagCatalog,
  requested : Array[String],
) -> Result[Array[BagTopic], String] {
  if requested.length() == 0 {
    let selected : Array[BagTopic] = []
    for topic in self.topics {
      selected.push(topic)
    }
    return Ok(selected)
  }
  let selected : Array[BagTopic] = []
  for name in requested {
    let topic = match bag_topic_by_name(self.topics, name) {
      Some(value) => value
      None => return Err("topic is not present in the bag: " + name)
    }
    if !contains_topic_name(selected, name) {
      selected.push(topic)
    }
  }
  Ok(selected)
}

///|
fn bag_topic_by_name(topics : Array[BagTopic], name : String) -> BagTopic? {
  for topic in topics {
    if topic.name == name {
      return Some(topic)
    }
  }
  None
}

///|
fn contains_topic_name(topics : Array[BagTopic], name : String) -> Bool {
  for topic in topics {
    if topic.name == name {
      return true
    }
  }
  false
}

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
/// Replay messages using injected clock, sleep, and publisher functions.
/// File order is preserved. Messages with decreasing timestamps are sent
/// immediately once their target time has passed.
pub async fn play(
  source : McapMessageSource,
  requested_topics : Array[String],
  rate_milli : UInt32,
  now_ms : () -> Int64,
  sleep_ms : async (Int32) -> Unit,
  publish : async (String, Bytes) -> Result[Unit, String],
) -> Result[UInt64, String] {
  if rate_milli == 0U {
    return Err("playback rate must be positive")
  }
  let start_ms = now_ms()
  let mut first_log_time_ns : UInt64? = None
  let mut published = 0UL
  while true {
    let message = match source.next() {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    match message {
      None => return Ok(published)
      Some(message) => {
        let first_time = match first_log_time_ns {
          Some(value) => value
          None => {
            first_log_time_ns = Some(message.log_time_ns)
            message.log_time_ns
          }
        }
        if requested_topics.length() > 0 &&
          !contains_string(requested_topics, message.topic_name) {
          continue
        }
        let target_ms = match
          playback_target_ms(message.log_time_ns, first_time, rate_milli) {
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
