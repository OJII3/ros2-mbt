///|
/// The collection shape of a ROS message field.
pub(all) enum MessageFieldCollection {
  Scalar
  FixedArray(Int)
  Sequence
  BoundedSequence(Int)
} derive(Eq, Debug)

///|
/// Return the fixed array length, if this collection is a fixed array.
pub fn MessageFieldCollection::fixed_array_length(
  self : MessageFieldCollection,
) -> Int? {
  match self {
    FixedArray(length) => Some(length)
    _ => None
  }
}

///|
/// Return whether this collection is a variable-length sequence.
pub fn MessageFieldCollection::is_sequence(
  self : MessageFieldCollection,
) -> Bool {
  match self {
    Sequence | BoundedSequence(_) => true
    _ => false
  }
}

///|
/// Return the maximum sequence length, if one was declared.
pub fn MessageFieldCollection::sequence_bound(
  self : MessageFieldCollection,
) -> Int? {
  match self {
    BoundedSequence(length) => Some(length)
    _ => None
  }
}

///|
/// A field in a ROS `.msg` definition.
pub struct MessageField {
  type_name : String
  name : String
  collection : MessageFieldCollection
  string_upper_bound : Int?
  default_value : String?
} derive(Eq, Debug)

///|
/// A nested message type available to the code generator.
pub struct MessageTypeReference {
  ros_name : String
  moon_name : String
} derive(Eq, Debug)

///|
/// A scalar constant declared in a ROS `.msg` definition.
pub struct MessageConstant {
  type_name : String
  name : String
  value : String
} derive(Eq, Debug)

///|
/// A parsed ROS message definition containing supported primitive fields.
pub struct MessageDefinition {
  package_name : String
  interface_namespace : String
  type_name : String
  fields : Array[MessageField]
  constants : Array[MessageConstant]
  nested_types : Array[MessageTypeReference]
} derive(Eq, Debug)

///|
/// A parsed ROS service definition containing request and response messages.
pub struct ServiceDefinition {
  package_name : String
  service_name : String
  request : MessageDefinition
  response : MessageDefinition
} derive(Eq, Debug)

///|
pub extend MessageFieldCollection with Eq::{not_equal, equal}

///|
pub extend MessageFieldCollection with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend MessageField with Eq::{not_equal, equal}

///|
pub extend MessageField with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend MessageTypeReference with Eq::{not_equal, equal}

///|
pub extend MessageTypeReference with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend MessageConstant with Eq::{not_equal, equal}

///|
pub extend MessageConstant with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend MessageDefinition with Eq::{not_equal, equal}

///|
pub extend MessageDefinition with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ServiceDefinition with Eq::{not_equal, equal}

///|
pub extend ServiceDefinition with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Create a message field descriptor.
pub fn MessageField::new(type_name : String, name : String) -> MessageField {
  {
    type_name,
    name,
    collection: Scalar,
    string_upper_bound: None,
    default_value: None,
  }
}

///|
/// Return a copy of the field with an explicit collection shape.
pub fn MessageField::with_collection(
  self : MessageField,
  collection : MessageFieldCollection,
) -> MessageField {
  { ..self, collection, }
}

///|
/// Return a copy of the field with a bounded ROS string type.
pub fn MessageField::with_string_upper_bound(
  self : MessageField,
  string_upper_bound : Int,
) -> MessageField {
  { ..self, string_upper_bound: Some(string_upper_bound), }
}

///|
/// Return the normalized MoonBit literal for a ROS field default, if present.
pub fn MessageField::default_value(self : MessageField) -> String? {
  self.default_value
}

///|
fn MessageField::with_default_value(
  self : MessageField,
  default_value : String,
) -> MessageField {
  { ..self, default_value: Some(default_value), }
}

///|
/// Return the ROS type spelling of this field.
pub fn MessageField::type_name(self : MessageField) -> String {
  self.type_name
}

///|
/// Return the field identifier.
pub fn MessageField::name(self : MessageField) -> String {
  self.name
}

///|
/// Return whether the field is scalar, fixed-size, or a sequence.
pub fn MessageField::collection(self : MessageField) -> MessageFieldCollection {
  self.collection
}

///|
/// Return the maximum length for a bounded ROS string or wide-string field.
pub fn MessageField::string_upper_bound(self : MessageField) -> Int? {
  self.string_upper_bound
}

///|
/// Create a nested message type reference for the code generator.
pub fn MessageTypeReference::new(
  ros_name : String,
  moon_name : String,
) -> MessageTypeReference {
  { ros_name, moon_name, }
}

///|
/// Return the ROS spelling of a nested message type.
pub fn MessageTypeReference::ros_name(self : MessageTypeReference) -> String {
  self.ros_name
}

///|
/// Return the MoonBit type name used in generated code.
pub fn MessageTypeReference::moon_name(self : MessageTypeReference) -> String {
  self.moon_name
}

///|
/// Create a message constant descriptor.
pub fn MessageConstant::new(
  type_name : String,
  name : String,
  value : String,
) -> MessageConstant {
  { type_name, name, value, }
}

///|
/// Return the ROS type spelling of this constant.
pub fn MessageConstant::type_name(self : MessageConstant) -> String {
  self.type_name
}

///|
/// Return the constant identifier.
pub fn MessageConstant::name(self : MessageConstant) -> String {
  self.name
}

///|
/// Return the source literal spelling of this constant.
pub fn MessageConstant::value(self : MessageConstant) -> String {
  self.value
}

///|
/// Create a validated message definition from its fields.
pub fn MessageDefinition::new(
  package_name : String,
  interface_namespace : String,
  type_name : String,
  fields : Array[MessageField],
) -> Result[MessageDefinition, String] {
  let nested_types : Array[MessageTypeReference] = []
  MessageDefinition::new_with_types(
    package_name, interface_namespace, type_name, fields, nested_types,
  )
}

///|
/// Create a validated message definition with nested message type references.
pub fn MessageDefinition::new_with_types(
  package_name : String,
  interface_namespace : String,
  type_name : String,
  fields : Array[MessageField],
  nested_types : Array[MessageTypeReference],
) -> Result[MessageDefinition, String] {
  if !rosidl_identifier(package_name) ||
    !rosidl_identifier(interface_namespace) ||
    !rosidl_identifier(type_name) {
    return Err("ROS message package, namespace, and type must be identifiers")
  }
  for nested_type in nested_types {
    if !rosidl_type_reference_name(nested_type.ros_name) {
      return Err("ROS nested message type names must be identifiers or paths")
    }
    if !rosidl_moon_type_reference_name(nested_type.moon_name) {
      return Err(
        "MoonBit nested message type names must be identifiers or qualified references",
      )
    }
  }
  for index in 0..<fields.length() {
    let field = fields[index]
    for previous_index in 0..<index {
      if fields[previous_index].name == field.name {
        return Err("ROS message field names must be unique")
      }
    }
    if !rosidl_identifier(field.name) {
      return Err("ROS message field names must be identifiers")
    }
    match field.string_upper_bound {
      Some(bound) =>
        if (field.type_name != "string" && field.type_name != "wstring") ||
          bound <= 0 {
          return Err("ROS string upper bounds require a positive bound")
        }
      None => ()
    }
    match rosidl_moon_type_for_field(field.type_name, nested_types) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    match field.collection {
      FixedArray(length) =>
        if length <= 0 {
          return Err("ROS fixed array lengths must be positive")
        }
      Scalar => ()
      Sequence => ()
      BoundedSequence(length) =>
        if length <= 0 {
          return Err("ROS bounded sequence lengths must be positive")
        }
    }
  }
  Ok({
    package_name,
    interface_namespace,
    type_name,
    fields,
    constants: [],
    nested_types,
  })
}

///|
/// Add validated constants to a parsed message definition.
pub fn MessageDefinition::with_constants(
  self : MessageDefinition,
  constants : Array[MessageConstant],
) -> Result[MessageDefinition, String] {
  for index in 0..<constants.length() {
    let constant = constants[index]
    for previous_index in 0..<index {
      if constants[previous_index].name == constant.name {
        return Err("ROS message constant names must be unique")
      }
    }
    if !rosidl_constant_identifier(constant.name) {
      return Err("ROS message constant names must be uppercase identifiers")
    }
    match rosidl_constant_literal(constant.type_name, constant.value) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok({ ..self, constants, })
}

///|
/// Return the nested type references used by this definition.
pub fn MessageDefinition::nested_types(
  self : MessageDefinition,
) -> Array[MessageTypeReference] {
  self.nested_types
}

///|
/// Return the ROS package name.
pub fn MessageDefinition::package_name(self : MessageDefinition) -> String {
  self.package_name
}

///|
/// Return the ROS interface namespace, usually `msg`.
pub fn MessageDefinition::interface_namespace(
  self : MessageDefinition,
) -> String {
  self.interface_namespace
}

///|
/// Return the ROS message type name.
pub fn MessageDefinition::type_name(self : MessageDefinition) -> String {
  self.type_name
}

///|
/// Return the parsed scalar fields.
pub fn MessageDefinition::fields(
  self : MessageDefinition,
) -> Array[MessageField] {
  self.fields
}

///|
/// Return the declared constants.
pub fn MessageDefinition::constants(
  self : MessageDefinition,
) -> Array[MessageConstant] {
  self.constants
}

///|
/// Create a service definition from its request and response messages.
pub fn ServiceDefinition::new(
  package_name : String,
  service_name : String,
  request : MessageDefinition,
  response : MessageDefinition,
) -> Result[ServiceDefinition, String] {
  if !rosidl_identifier(package_name) || !rosidl_identifier(service_name) {
    return Err("ROS service package and type must be identifiers")
  }
  if request.package_name() != package_name ||
    request.interface_namespace() != "srv" ||
    request.type_name() != service_name + "_Request" {
    return Err("ROS service request definition has the wrong identity")
  }
  if response.package_name() != package_name ||
    response.interface_namespace() != "srv" ||
    response.type_name() != service_name + "_Response" {
    return Err("ROS service response definition has the wrong identity")
  }
  Ok({ package_name, service_name, request, response, })
}

///|
/// Return the ROS package name.
pub fn ServiceDefinition::package_name(self : ServiceDefinition) -> String {
  self.package_name
}

///|
/// Return the ROS service name.
pub fn ServiceDefinition::service_name(self : ServiceDefinition) -> String {
  self.service_name
}

///|
/// Return the service request message definition.
pub fn ServiceDefinition::request(
  self : ServiceDefinition,
) -> MessageDefinition {
  self.request
}

///|
/// Return the service response message definition.
pub fn ServiceDefinition::response(
  self : ServiceDefinition,
) -> MessageDefinition {
  self.response
}

///|
