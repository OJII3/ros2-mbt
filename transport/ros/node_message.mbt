///|
/// Create a publisher using the message identity and codec from one descriptor.
pub async fn[T] RosNode::create_publisher_for(
  self : RosNode,
  topic_name : String,
  message_type : @ros_types.RosMessageType[T],
  qos~ : @rtps.SedpQos = @rtps.SedpQos::reliable(),
) -> Result[RosNodePublisher[T], String] {
  let topic = match message_type.topic(topic_name) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  self.create_publisher(
    topic,
    message_type.type_hash(),
    fn(message) { message_type.encode(message) },
    qos~,
  )
}

///|
/// Create a subscription using the message identity and codec from one descriptor.
pub async fn[T] RosNode::create_subscription_for(
  self : RosNode,
  topic_name : String,
  message_type : @ros_types.RosMessageType[T],
  callback : async (T) -> Unit,
  qos~ : @rtps.SedpQos = @rtps.SedpQos::reliable(),
) -> Result[Unit, String] {
  let topic = match message_type.topic(topic_name) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  self.create_subscription(
    topic,
    message_type.type_hash(),
    fn(payload) { message_type.decode(payload) },
    callback,
    qos~,
  )
}
