///|
async test "repeated playback drains after every completed pass" {
  let mut pass = 0
  let events : Array[String] = []
  let result = play_repeatedly(
    true,
    async fn() {
      @async.sleep(0)
      pass += 1
      if pass > 3 {
        return Err("stop")
      }
      events.push("pass")
      Ok(1UL)
    },
    async fn(_message_count) {
      @async.sleep(0)
      events.push("after")
    },
  )
  assert_eq(result, Err("stop"))
  assert_eq(events, ["pass", "after", "pass", "after", "pass", "after"])
}

///|
async test "single playback drains after the pass" {
  let events : Array[String] = []
  let result = play_repeatedly(
    false,
    async fn() {
      @async.sleep(0)
      Ok(2UL)
    },
    async fn(message_count) {
      @async.sleep(0)
      events.push("after \{message_count}")
    },
  )
  assert_eq(result, Ok(2UL))
  assert_eq(events, ["after 2"])
}
