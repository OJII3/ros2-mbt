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
/// Number of frames expected from one publisher run.
const IMAGE_COUNT : Int32 = 10

///|
/// A complete 10-frame stream must finish well before the scenario timeout.
const IMAGE_STREAM_MAX_MS : Int64 = 10000L

///|
fn is_expected_image(image : @sensor_msgs.Image) -> Bool {
  if image.width().reinterpret_as_int() != IMAGE_WIDTH ||
    image.height().reinterpret_as_int() != IMAGE_HEIGHT ||
    image.encoding() != "rgb8" ||
    image.is_bigendian() != 0 ||
    image.step().reinterpret_as_int() != IMAGE_WIDTH * 3 {
    return false
  }
  let data = image.data()
  if data.length() != IMAGE_BYTE_LENGTH {
    return false
  }
  for index in 0..<IMAGE_BYTE_LENGTH.to_int() {
    if data[index] != (index % 251).to_byte() {
      return false
    }
  }
  true
}

///|
/// Receive and validate a deterministic camera-sized Image stream.
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
      "moon_image_listener",
      domain_id=config.domain_id,
      participant_id=43U,
      ip=config.ip,
      multicast_interface?=config.multicast_interface,
    ) {
    Ok(value) => value
    Err(message) => {
      println(message)
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
  let seen = Array::make(IMAGE_COUNT.to_int(), false)
  let mut received : Int32 = 0
  let mut first_ms : Int64 = -1L
  match
    node.create_subscription_for("/image", @sensor_msgs.Image::type_support(), fn(
      image,
    ) {
      let index = image.header().stamp().sec()
      if index < 0 ||
        index >= IMAGE_COUNT ||
        seen[index.to_int()] ||
        !is_expected_image(image) {
        println(
          "IMAGE_INVALID index=" +
          index.to_string() +
          " bytes=" +
          image.data().length().to_string(),
        )
        executor.shutdown()
        return
      }
      if first_ms < 0L {
        first_ms = @async.now()
      }
      seen[index.to_int()] = true
      received += 1
      println(
        "received image-" +
        index.to_string() +
        " bytes=" +
        image.data().length().to_string(),
      )
      if received == IMAGE_COUNT {
        let elapsed_ms = @async.now() - first_ms
        if elapsed_ms <= IMAGE_STREAM_MAX_MS {
          println(
            "IMAGE_STREAM_OK count=" +
            IMAGE_COUNT.to_string() +
            " bytes=" +
            (IMAGE_BYTE_LENGTH * IMAGE_COUNT).to_string() +
            " elapsed_ms=" +
            elapsed_ms.to_string(),
          )
        } else {
          println(
            "IMAGE_STREAM_SLOW count=" +
            IMAGE_COUNT.to_string() +
            " elapsed_ms=" +
            elapsed_ms.to_string(),
          )
        }
        executor.shutdown()
      }
    }) {
    Ok(_) => ()
    Err(message) => {
      println(message)
      ignore(node.dispose_and_close())
      return
    }
  }
  eprintln(
    "IMAGE_LISTENER_READY width=" +
    IMAGE_WIDTH.to_string() +
    " height=" +
    IMAGE_HEIGHT.to_string() +
    " count=" +
    IMAGE_COUNT.to_string(),
  )
  match executor.spin() {
    Ok(_) => ()
    Err(message) => println(message)
  }
  match node.dispose_and_close() {
    Ok(_) => ()
    Err(message) => println(message)
  }
}
