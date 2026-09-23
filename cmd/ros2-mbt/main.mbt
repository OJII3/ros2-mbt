///|
const DEFAULT_SPIN_TIME_MS : String = "1000"

///|
const DEFAULT_MEASUREMENT_TIME_MS : String = "5000"

///|
fn positive_option(
  matches : @argparse.Matches,
  name : String,
  default_value : String,
) -> Result[Int, String] {
  let value = match matches.values.get(name) {
    Some([value]) => value
    Some(_) => return Err("option --" + name + " must have one value")
    None => default_value
  }
  let parsed = @string.parse_int(value) catch {
    _ => return Err("option --" + name + " must be a positive integer")
  }
  if parsed <= 0 {
    return Err("option --" + name + " must be a positive integer")
  }
  Ok(parsed)
}

///|
fn topic_list_command() -> @argparse.Command {
  @argparse.Command("list", about="List discovered ROS topics.", options=[
    @argparse.OptionArg(
      "spin-time-ms",
      about="Discovery duration in milliseconds.",
      default_values=[DEFAULT_SPIN_TIME_MS],
    ),
  ])
}

///|
fn topic_hz_command() -> @argparse.Command {
  @argparse.Command(
    "hz",
    about="Measure the arrival rate of one ROS topic.",
    options=[
      @argparse.OptionArg(
        "spin-time-ms",
        about="Discovery duration in milliseconds.",
        default_values=[DEFAULT_SPIN_TIME_MS],
      ),
      @argparse.OptionArg(
        "duration-ms",
        about="Measurement duration in milliseconds.",
        default_values=[DEFAULT_MEASUREMENT_TIME_MS],
      ),
    ],
    positionals=[@argparse.PositionArg("topic", about="ROS topic name.")],
  )
}

///|
fn topic_echo_command() -> @argparse.Command {
  @argparse.Command(
    "echo",
    about="Echo messages from a ROS topic, detecting its type from discovery.",
    options=[
      @argparse.OptionArg(
        "spin-time-ms",
        about="Discovery duration in milliseconds.",
        default_values=[DEFAULT_SPIN_TIME_MS],
      ),
    ],
    positionals=[@argparse.PositionArg("topic", about="ROS topic name.")],
  )
}

///|
fn topic_command() -> @argparse.Command {
  @argparse.Command(
    "topic",
    about="Inspect ROS topics.",
    subcommands=[topic_list_command(), topic_hz_command(), topic_echo_command()],
    subcommand_required=true,
  )
}

///|
fn node_list_command() -> @argparse.Command {
  @argparse.Command("list", about="List discovered ROS nodes.", options=[
    @argparse.OptionArg(
      "spin-time-ms",
      about="Discovery duration in milliseconds.",
      default_values=[DEFAULT_SPIN_TIME_MS],
    ),
  ])
}

///|
fn node_command() -> @argparse.Command {
  @argparse.Command(
    "node",
    about="Inspect ROS nodes.",
    subcommands=[node_list_command()],
    subcommand_required=true,
  )
}

///|
fn root_command() -> @argparse.Command {
  @argparse.Command(
    "ros2-mbt",
    about="Small ROS 2 discovery and diagnostics CLI for ros2-mbt.",
    subcommands=[topic_command(), node_command()],
    subcommand_required=true,
  )
}

///|
fn positional_value(
  matches : @argparse.Matches,
  name : String,
) -> Result[String, String] {
  match matches.values.get(name) {
    Some([value]) => Ok(value)
    Some(_) => Err("positional argument " + name + " must have one value")
    None => Err("missing positional argument " + name)
  }
}

///|
async fn dispatch_topic(matches : @argparse.Matches) -> Result[Unit, String] {
  match matches.subcommand {
    None => Err("a topic subcommand is required")
    Some(("list", list_matches)) => {
      let spin_time_ms = match
        positive_option(list_matches, "spin-time-ms", DEFAULT_SPIN_TIME_MS) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      run_topic_list(spin_time_ms)
    }
    Some(("hz", hz_matches)) => {
      let topic = match positional_value(hz_matches, "topic") {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let spin_time_ms = match
        positive_option(hz_matches, "spin-time-ms", DEFAULT_SPIN_TIME_MS) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let duration_ms = match
        positive_option(hz_matches, "duration-ms", DEFAULT_MEASUREMENT_TIME_MS) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      run_topic_hz(topic, spin_time_ms, duration_ms)
    }
    Some(("echo", echo_matches)) => {
      let topic = match positional_value(echo_matches, "topic") {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let spin_time_ms = match
        positive_option(echo_matches, "spin-time-ms", DEFAULT_SPIN_TIME_MS) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      run_topic_echo(topic, spin_time_ms)
    }
    Some((name, _)) => Err("unknown topic subcommand: " + name)
  }
}

///|
async fn dispatch_node(matches : @argparse.Matches) -> Result[Unit, String] {
  match matches.subcommand {
    None => Err("a node subcommand is required")
    Some(("list", list_matches)) => {
      let spin_time_ms = match
        positive_option(list_matches, "spin-time-ms", DEFAULT_SPIN_TIME_MS) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      run_node_list(spin_time_ms)
    }
    Some((name, _)) => Err("unknown node subcommand: " + name)
  }
}

///|
async fn main {
  let matches = root_command().parse()
  let result = match matches.subcommand {
    Some(("topic", topic_matches)) => dispatch_topic(topic_matches)
    Some(("node", node_matches)) => dispatch_node(node_matches)
    Some((name, _)) => Err("unknown subcommand: " + name)
    None => Err("a subcommand is required")
  }
  match result {
    Ok(_) => ()
    Err(message) => println("error: " + message)
  }
}
