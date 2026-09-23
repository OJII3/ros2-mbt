# ros2-mbt

Native ROS 2 interoperability for MoonBit.

`ros2-mbt` lets MoonBit programs communicate with ROS 2 nodes directly over
DDS/RTPS, without linking against a ROS 2 client library. It provides the
building blocks for ROS 2 topics, services, actions, parameters, discovery,
and serialization.

> **Status:** `0.2.0` — experimental. APIs and interoperability coverage may
> change before `1.0.0`.

## What you can do

- Publish and subscribe to ROS 2 topics with best-effort or reliable QoS.
- Call and implement ROS 2 services.
- Use a ROS 2 Action client, including feedback, status, and cancellation.
- Read and set ROS 2 parameters.
- Encode and decode RTPS and CDR data in MoonBit.
- Generate MoonBit codecs from `.msg`, `.srv`, and `.action` definitions.
- Use codecs for a selection of common ROS 2 Jazzy messages out of the box.

## Installation

Add the module to a MoonBit project:

```sh
moon add OJII3/ros2-mbt@0.2.0
```

The library currently targets MoonBit's native backend. Most applications use
the `ros` and `transport` packages:

```moonbit nocheck
///|
import {
  "OJII3/ros2-mbt/ros",
  "OJII3/ros2-mbt/transport",
}
```

The module is organized into focused packages:

- `cdr` — CDR readers and writers
- `ros` — ROS names, endpoints, discovery data, and message types
- `rosidl` — `.msg`, `.srv`, and `.action` parsing and codec generation
- `rtps` — RTPS wire and discovery types
- `transport` — UDP transport, discovery, topics, services, and actions

Add the native diagnostic CLI to a Nix flake:

In the flake inputs:

```nix
inputs = {
  ros2-mbt.url = "github:OJII3/ros2-mbt";
};
```

Then add the package to a devShell:

```nix
devShells.${system}.default = pkgs.mkShell {
  packages = [
    inputs.ros2-mbt.packages.${system}.ros2-mbt
  ];
};
```

## Try the examples

The examples require Nix and a ROS 2 Jazzy environment. Start a ROS 2 CLI
subscriber in one terminal:

```sh
nix develop .#ros2
ros2 topic echo /chatter std_msgs/msg/String
```

In a second terminal, run the MoonBit publisher from the repository root:

```sh
nix develop .#ros2
moon run examples/talker
```

The `ros2-mbt` CLI can discover a topic's message type and decode its messages
from the installed ROS `.msg` definitions:

```sh
ros2-mbt topic echo /chatter
```

`topic echo` looks up definitions under `AMENT_PREFIX_PATH` and decodes nested
messages, primitive fields, arrays, and strings in MoonBit. It does not invoke
the `ros2` executable. Reliable and best-effort publishers are received using
subscriptions with compatible reliability and durability. The current reader
transport attaches to one publisher per invocation. The talker examples send
to every discovered matching subscription and continue processing discovery
while publishing, so subscriptions that join later receive subsequent samples.

The publisher publishes five samples without waiting for a ROS 2 subscriber.
It continues processing discovery while publishing, so a compatible
subscriber that joins while the example is running receives later samples.
The examples exit after those five publishes. To test the opposite direction,
run a ROS 2 publisher and the MoonBit listener:

```sh
# Terminal 1
nix develop .#ros2
ros2 topic pub --qos-reliability reliable /chatter std_msgs/msg/String \
  "{data: hello from ROS 2}"

# Terminal 2
nix develop .#ros2
moon run examples/listener
```

For communication across hosts, set `ROS2_MBT_IP` to the MoonBit host's
reachable IPv4 address and use the same `ROS_DOMAIN_ID` on both sides:

```sh
export ROS2_MBT_IP=192.168.1.20
export ROS_DOMAIN_ID=0
moon run examples/talker
```

The repository includes additional examples for WString topics, services,
actions, and parameters:

| Example | Purpose |
| --- | --- |
| `examples/talker` / `examples/listener` | String topic publisher and subscriber |
| `examples/wstring_talker` / `wstring_listener` | WString topic publisher and subscriber |
| `examples/service_server` / `service_client` | ROS 2 service server and client |
| `examples/action_client` | Fibonacci Action client |
| `examples/parameter_client` | ROS 2 parameter client |

## Supported scope

The current release has been tested with:

| Area | Scope |
| --- | --- |
| MoonBit backend | Native |
| Operating systems | Linux and macOS |
| ROS 2 distribution | Jazzy |
| DDS implementations | Cyclone DDS 11.0.1 and Fast DDS 3.6.2 |
| ROS 2 interfaces | Selected codecs from `std_msgs`, `builtin_interfaces`, `geometry_msgs`, `sensor_msgs`, `nav_msgs`, `action_msgs`, and `rmw_dds_common` |

This is a DDS/RTPS compatibility layer, not a complete ROS 2 implementation.
The supported message, QoS, and graph-interoperability surface will grow over
time.

## Known limitations

- The API is experimental and may change between minor releases before 1.0.
- Only the native backend is currently supported by the transport layer.
- ROS graph interoperability is partial; common topic and service discovery
  paths are covered, but full graph parity is not.
- DDS discovery requires a network that permits the required UDP
  multicast/unicast traffic. Use `ROS2_MBT_MULTICAST_IP` when the multicast
  interface must be selected explicitly.
- On macOS, running multiple participants on the same host can be unreliable
  because of UDP multicast port sharing.
- Not every ROS 2 message type or QoS combination has been tested.

## Development

Enter the development environment and update MoonBit dependencies:

```sh
nix develop
moon update
```

Run formatting, type checking, and native tests:

```sh
just verify
```

Run the full ROS 2 interoperability suite in Podman:

```sh
just interop-podman
```

## License

MIT. See [LICENSE](LICENSE).
