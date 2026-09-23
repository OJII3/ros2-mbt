///|
fn print_dynamic_sample(
  schema : @introspection.MessageSchema,
  payload : Bytes,
) -> Result[Unit, String] {
  let value = match @dynamic.decode(schema, payload) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let yaml = match @dynamic.to_yaml(value) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  println(yaml.trim_end(chars="\n"))
  println("---")
  Ok(())
}

///|
fn find_topic_publication(
  participant : @transport.RosParticipant,
  ros_name : String,
) -> Result[@rtps.SedpEndpointData, String] {
  let dds_name = match @ros.ros_topic_to_dds(ros_name) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let mut first_publication : @rtps.SedpEndpointData? = None
  for publication in participant.graph().publications() {
    if publication.topic_name() != dds_name {
      continue
    }
    match first_publication {
      None => first_publication = Some(publication)
      Some(first) if first.type_name() != publication.type_name() =>
        return Err("topic has publishers with different message types")
      Some(_) => ()
    }
  }
  match first_publication {
    Some(value) => Ok(value)
    None => Err("no publication was discovered for " + ros_name)
  }
}

///|
fn echo_reader_id() -> Result[@rtps.EntityId, String] {
  @rtps.EntityId::new(b"ech", 0x04)
}

///|
async fn echo_best_effort(
  subscription : @transport.RosSubscription,
  schema : @introspection.MessageSchema,
) -> Result[Unit, String] {
  while true {
    match subscription.receive() {
      Ok((payload, _)) =>
        match print_dynamic_sample(schema, payload) {
          Ok(_) => ()
          Err(message) => {
            subscription.close()
            return Err(message)
          }
        }
      Err(message) => {
        subscription.close()
        return Err(message)
      }
    }
  } nobreak {
    subscription.close()
    Ok(())
  }
}

///|
async fn echo_reliable(
  subscription : @transport.ReliableRosSubscription,
  schema : @introspection.MessageSchema,
) -> Result[Unit, String] {
  while true {
    match subscription.receive() {
      Ok((payload, _)) =>
        match print_dynamic_sample(schema, payload) {
          Ok(_) => ()
          Err(message) => {
            subscription.close()
            return Err(message)
          }
        }
      Err(message) => {
        subscription.close()
        return Err(message)
      }
    }
  } nobreak {
    subscription.close()
    Ok(())
  }
}

///|
async fn run_topic_echo(
  topic_name : String,
  spin_time_ms : Int,
) -> Result[Unit, String] {
  let ros_name = match normalize_ros_topic_name(topic_name) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let cli = match new_cli_participant(false) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  @async.with_task_group() <| group => {
    group.spawn_bg(no_wait=true) <| () => {
      ignore(cli.participant.announce_spdp_forever(CLI_DISCOVERY_INTERVAL_MS))
    }
    let publication = match
      spin_discovery(cli.participant, spin_time_ms, false) {
      Ok(_) =>
        match find_topic_publication(cli.participant, ros_name) {
          Ok(value) => value
          Err(message) => {
            cli.participant.close()
            return Err(message)
          }
        }
      Err(message) => {
        cli.participant.close()
        return Err(message)
      }
    }
    let ros_type_name = ros_type_name_from_dds(publication.type_name())
    let schema = match @introspection.load_message_schema(ros_type_name) {
      Ok(value) => value
      Err(message) => {
        cli.participant.close()
        return Err(message)
      }
    }
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
    let publisher_qos = match publication.qos() {
      Ok(value) => value
      Err(message) => {
        cli.participant.close()
        return Err(message)
      }
    }
    let requested_qos = @rtps.SedpQos::new(
      publisher_qos.reliability(),
      publisher_qos.durability(),
      publisher_qos.history(),
      publisher_qos.depth(),
    )
    let reader_id = match echo_reader_id() {
      Ok(value) => value
      Err(message) => {
        cli.participant.close()
        return Err(message)
      }
    }
    match
      cli.participant.register_topic_endpoint(
        topic,
        Subscription,
        reader_id,
        requested_qos,
      ) {
      Ok(_) => ()
      Err(message) => {
        cli.participant.close()
        return Err(message)
      }
    }
    let (discovery, user_socket) = cli.participant.into_parts()
    let is_reliable = publisher_qos.reliability() == @rtps.RELIABILITY_RELIABLE
    let result = if is_reliable {
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
          discovery.close()
          return Err(message)
        }
      }
      echo_reliable(subscription, schema)
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
          discovery.close()
          return Err(message)
        }
      }
      echo_best_effort(subscription, schema)
    }
    discovery.close()
    result
  }
}
