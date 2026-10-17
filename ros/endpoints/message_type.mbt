///|
/// A ROS message's wire identity and CDR codecs.
///
/// The descriptor keeps the ROS interface name, RIHS01 type hash, and codecs
/// together so an endpoint can advertise and serialize the same message type.
pub struct RosMessageType[T] {
  package_name : String
  interface_namespace : String
  type_name : String
  type_hash : String
  encoder : (T) -> Result[Bytes, String]
  decoder : (Bytes) -> Result[T, String]
}

///|
/// Create a message type descriptor.
pub fn[T] RosMessageType::new(
  package_name : String,
  interface_namespace : String,
  type_name : String,
  type_hash : String,
  encoder : (T) -> Result[Bytes, String],
  decoder : (Bytes) -> Result[T, String],
) -> RosMessageType[T] {
  { package_name, interface_namespace, type_name, type_hash, encoder, decoder, }
}

///|
/// Create a topic identity for this message type.
pub fn[T] RosMessageType::topic(
  self : RosMessageType[T],
  ros_name : String,
) -> Result[RosTopic, String] {
  RosTopic::new(
    ros_name,
    self.package_name,
    self.interface_namespace,
    self.type_name,
  )
}

///|
/// Return this message type's RIHS01 type hash.
pub fn[T] RosMessageType::type_hash(self : RosMessageType[T]) -> String {
  self.type_hash
}

///|
/// Encode a message using this type's CDR codec.
pub fn[T] RosMessageType::encode(
  self : RosMessageType[T],
  message : T,
) -> Result[Bytes, String] {
  (self.encoder)(message)
}

///|
/// Decode a message using this type's CDR codec.
pub fn[T] RosMessageType::decode(
  self : RosMessageType[T],
  payload : Bytes,
) -> Result[T, String] {
  (self.decoder)(payload)
}
