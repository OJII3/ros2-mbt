///|
fn print_echo_sample(type_name : String, payload : Bytes) -> Unit {
  let string_type = @ros.ros_type_path_to_dds("std_msgs/msg/String").unwrap()
  if type_name == string_type {
    match @std_msgs.StringMessage::from_cdr_bytes(payload) {
      Ok(message) => println("data: " + message.data())
      Err(message) =>
        println(
          "error decoding " + ros_type_name_from_dds(type_name) + ": " + message,
        )
    }
  } else {
    println(
      "type: " +
      ros_type_name_from_dds(type_name) +
      "\nserialized CDR payload: " +
      payload.length().to_string() +
      " bytes (no decoder registered)",
    )
  }
}

///|
async fn echo_best_effort(
  subscription : @transport.RosSubscription,
  type_name : String,
) -> Result[Unit, String] {
  while true {
    match subscription.receive() {
      Ok((payload, _)) => print_echo_sample(type_name, payload)
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
  type_name : String,
) -> Result[Unit, String] {
  while true {
    match subscription.receive() {
      Ok((payload, _)) => print_echo_sample(type_name, payload)
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
  let publication_result = @async.with_task_group() <| group => {
    group.spawn_bg(no_wait=true) <| () => {
      ignore(cli.participant.announce_spdp_forever(CLI_DISCOVERY_INTERVAL_MS))
    }
    match spin_discovery(cli.participant, spin_time_ms, false) {
      Ok(_) => find_publication(cli.participant, ros_name)
      Err(message) => Err(message)
    }
  }
  match publication_result {
    Err(message) => {
      cli.participant.close()
      Err(message)
    }
    Ok(publication) => {
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
      let is_reliable = match publication.qos() {
        Ok(qos) => qos.reliability() == @rtps.RELIABILITY_RELIABLE
        Err(message) => {
          cli.participant.close()
          return Err(message)
        }
      }
      let (discovery, user_socket) = cli.participant.into_parts()
      discovery.close()
      let reader_id = match @rtps.EntityId::new(b"ech", 0x04) {
        Ok(value) => value
        Err(message) => {
          user_socket.close()
          return Err(message)
        }
      }
      if is_reliable {
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
            return Err(message)
          }
        }
        echo_reliable(subscription, publication.type_name())
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
            return Err(message)
          }
        }
        echo_best_effort(subscription, publication.type_name())
      }
    }
  }
}
