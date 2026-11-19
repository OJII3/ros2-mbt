///|
/// Width of the camera-sized test frame.
const IMAGE_WIDTH : Int32 = 640

///|
/// Height of the camera-sized test frame.
const IMAGE_HEIGHT : Int32 = 480

///|
/// Serialized byte length of a tightly packed RGB8 frame.
const IMAGE_BYTE_LENGTH : Int32 = IMAGE_WIDTH * IMAGE_HEIGHT * 3

///|
/// Number of frames sent by one run.
const IMAGE_COUNT : Int32 = 10

///|
/// Twenty frames per second at 640x480 RGB8 is about 18 MB/s.
const IMAGE_PERIOD_MS : Int32 = 50

///|
/// Stop when no subscriber appears; the stream itself should start as soon as
/// discovery reports a match.
const IMAGE_SUBSCRIBER_TIMEOUT_MS : Int64 = 30000L

///|
fn image_data() -> Array[Byte] {
  Array::makei(IMAGE_BYTE_LENGTH.to_int(), fn(index) { (index % 251).to_byte() })
}

///|
/// Publish a deterministic camera-sized Image stream through the node API.
async fn main {
  let config = match @config.load() {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let node = match
    @transport.RosNode::new_ddsi(
      "/demo",
      "moon_image_talker",
      domain_id=config.domain_id,
      participant_id=42U,
      ip=config.ip,
      multicast_interface?=config.multicast_interface,
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return
    }
  }
  let publisher = match
    node.create_publisher_for("/image", @sensor_msgs.Image::type_support()) {
    Ok(value) => value
    Err(message) => {
      println(message)
      ignore(node.dispose_and_close())
      return
    }
  }
  let executor = @transport.Executor::new()
  match executor.add_node(node) {
    Ok(_) => ()
    Err(message) => {
      println(message)
      ignore(node.dispose_and_close())
      return
    }
  }
  let width = IMAGE_WIDTH.reinterpret_as_uint()
  let height = IMAGE_HEIGHT.reinterpret_as_uint()
  let step = (IMAGE_WIDTH * 3).reinterpret_as_uint()
  let data = image_data()
  let started_ms = @async.now()
  let mut streaming = false
  let mut next_index : Int32 = 0
  match
    node.create_timer(IMAGE_PERIOD_MS, async fn() {
      if !streaming {
        if publisher.subscriber_count() == 0 {
          if @async.now() - started_ms >= IMAGE_SUBSCRIBER_TIMEOUT_MS {
            eprintln("IMAGE_TALKER_TIMEOUT waiting for a subscriber")
            executor.shutdown()
          }
          return
        }
        streaming = true
      }
      if next_index >= IMAGE_COUNT {
        return
      }
      let index = next_index
      let image = @sensor_msgs.Image::new(
        @std_msgs.Header::new(
          @builtin_interfaces.Time::new(index, 0U),
          "image-" + index.to_string(),
        ),
        height,
        width,
        "rgb8",
        0,
        step,
        data,
      )
      match publisher.publish(image) {
        Ok(_) => println("published image-" + index.to_string())
        Err(message) => {
          println(message)
          executor.shutdown()
          return
        }
      }
      next_index += 1
      if next_index == IMAGE_COUNT {
        eprintln(
          "IMAGE_TALKER_DONE count=" +
          IMAGE_COUNT.to_string() +
          " bytes=" +
          (IMAGE_BYTE_LENGTH * IMAGE_COUNT).to_string(),
        )
        executor.shutdown()
      }
    }) {
    Ok(_) => ()
    Err(message) => {
      println(message)
      executor.shutdown()
    }
  }
  match executor.spin() {
    Ok(_) => ()
    Err(message) => println(message)
  }
  match node.dispose_and_close() {
    Ok(_) => ()
    Err(message) => println(message)
  }
}
