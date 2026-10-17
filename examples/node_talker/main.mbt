///|
/// Publish five best-effort samples on `/chatter` using the node API.
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
      "moon_node_talker",
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
    node.create_publisher_for(
      "/chatter",
      @std_msgs.StringMessage::type_support(),
    ) {
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
  let mut count = 0
  match
    node.create_timer(1000, async fn() {
      count += 1
      match
        publisher.publish(@std_msgs.StringMessage::new("hello from RosNode")) {
        Ok(_) => println("published sample " + count.to_string())
        Err(message) => println(message)
      }
      if count == 5 {
        executor.shutdown()
      }
    }) {
    Ok(_) => ()
    Err(message) => {
      println(message)
      executor.shutdown()
      ignore(node.dispose_and_close())
      return
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
