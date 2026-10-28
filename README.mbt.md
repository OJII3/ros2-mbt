# ros2-mbt

Native ROS 2 interoperability for MoonBit.

`ros2-mbt` lets MoonBit programs communicate with ROS 2 nodes directly over
DDS/RTPS, without linking against a ROS 2 client library. It provides the
building blocks for ROS 2 topics, services, actions, parameters, discovery,
and serialization.

> **Status:** `0.9.0` — experimental. APIs and interoperability coverage may
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
moon add OJII3/ros2-mbt@0.9.0
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

`rtps/discovery.DiscoveryEngine` owns SPDP participant state and the SEDP
builtin writers, retained history, fragment assembly, and reliability control.
Feed decoded messages to `receive` and nondecreasing milliseconds to `advance`;
`next_deadline` tells the caller when to advance during idle periods. Explicit
`announce_spdp` and `announce_sedp` calls produce outgoing messages without I/O.
The caller schedules repeated SPDP announcements.

Effects contain locator-addressed RTPS messages and discovery events. Producing
effects consumes protocol sequence/count values, so failed sends must retry the
same effects. `transport/discovery.DiscoverySession` supplies the monotonic clock,
UDP receive/timer scheduling, and a serialized send queue. Socket failures retain
the original effects for `flush_outgoing` to retry while other peers can still
receive their queued datagrams. Unsupported transports and invalid destination
ports move to `take_rejected_outgoing` for caller inspection or rerouting, so
permanent failures cannot block the active queue. Concurrent SEDP announcements
wake an idle receive to recalculate its heartbeat deadline.

All local SEDP endpoints of a kind share the engine's builtin writer and sequence
space. Participant discovery or changed SPDP metadata replays registered samples;
unchanged SPDP refreshes do not create writes. History retains each endpoint's
latest announcement or dispose tombstone, answers compacted sequences with GAP,
and remains available independently of acknowledgements from other peers. Peers
without a supported metatraffic locator are skipped when announcing endpoints;
local registration and retained history remain available for supported peers.

Discovery fragment admission is bounded before allocation: 128 receive writers
across SPDP/SEDP (including undiscovered GUIDs), 16 incomplete samples, 1 MiB and
4096 fragments per sample, and 4 MiB aggregate payload plus fragment-presence
storage. SPDP uses best-effort fragment tracking with at most four incomplete
samples and a 256-sequence duplicate window per writer. Its fragment readers
expire five seconds after creation, without extending the deadline on traffic;
`next_deadline` exposes this cleanup even for undiscovered writers. SEDP receive
state is not expired by this cleanup. Rejected reliable samples remain retryable
after capacity frees. SEDP
history admits at most 1024 endpoint GUIDs and 16 MiB of serialized DATA and
fragments per builtin writer; dispose tombstones count toward these limits.
Sender reliability control state is limited to 256 peer/kind pairs. These bounds
do not cap all memory: discovered participants, per-endpoint receive high-water
marks, received sequence/GAP bookkeeping, and pending/rejected effects still need
application lifetime management. The supplied UDP adapter is IPv4-only; outgoing
locator selection matches the engine's configured destination transport kind.
Writer slots have no idle eviction and are released by participant removal or
engine recreation; completion or GAP releases incomplete sample storage. This is not full
RTPS context support: INFO_SRC and INFO_REPLY are not interpreted by discovery.

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
from the installed ROS `.msg` definitions or its built-in schemas for common
message types:

```sh
ros2-mbt topic echo /chatter
```

`topic echo` uses definitions under `AMENT_PREFIX_PATH` when available and
falls back to bundled schemas for message types supported by this project. It
decodes nested messages, primitive fields, arrays, and strings in MoonBit, and
does not invoke the `ros2` executable. Reliable and best-effort publishers are
received using subscriptions with compatible reliability and durability. The
current reader transport attaches to one publisher per invocation. The talker
examples send to every discovered matching subscription and continue
processing discovery while publishing, so subscriptions that join later
receive subsequent samples.

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
  multicast/unicast traffic. The `ros2-mbt` CLI uses `ROS2_MBT_IP` as its
  multicast interface by default. This defaults to loopback for local use.
  Set `ROS2_MBT_MULTICAST_IP` to an interface's local IPv4 address when ROS 2
  traffic uses a different network interface.
- On macOS, running multiple participants on the same host can be unreliable
  because of UDP multicast port sharing.
- Not every ROS 2 message type or QoS combination has been tested.

## Node and executor API

`transport.RosNode` groups publishers, subscriptions, and timers without
requiring user-defined node inheritance. `RosNode::new_ddsi` creates and
configures a fresh DDSI participant; participant IDs must be unique for each
participant on the same host and domain. The node API defaults to reliable,
volatile topic endpoints and supports configurable QoS
(`@rtps.SedpQos::reliable()` / `@rtps.SedpQos::best_effort()`). The example
uses `type_support()` to keep the ROS type name, type hash, and CDR codecs
together. Read published samples with `ros2 topic echo /chatter`.

```moonbit nocheck
import {
  "OJII3/ros2-mbt/ros/messages/std_msgs" @std_msgs,
  "OJII3/ros2-mbt/transport" @transport,
}

async main {
  let node = @transport.RosNode::new_ddsi(
    "/demo",
    "talker",
    domain_id=0U,
    participant_id=42U,
    ip=0x7F000001U,
  ).unwrap()
  let publisher = node.create_publisher_for(
    "/chatter",
    @std_msgs.StringMessage::type_support(),
  ).unwrap()
  node.create_timer(1000, async fn() {
    match publisher.publish(@std_msgs.StringMessage::new("hello")) {
      Ok(_) => ()
      Err(message) => println(message)
    }
  }).unwrap()
  let executor = @transport.Executor::new()
  executor.add_node(node).unwrap()
  ignore(executor.spin())
}
```

Run the finite publisher with `moon run examples/node_talker`; it reads
`ROS_DOMAIN_ID`, `ROS2_MBT_IP`, and `ROS2_MBT_MULTICAST_IP` from the environment.

`Executor::spin` reads each participant's user-data socket once and routes each
RTPS message to matching subscriptions and the reliable ROS graph endpoints.
Malformed RTPS datagrams and samples rejected by a subscription's decoder are
discarded, allowing later samples to be processed. It runs callbacks
sequentially and waits asynchronously for network input, timers, or
`Executor::shutdown()`.
The node API supports both reliable and best-effort topic QoS, with automatic
HEARTBEAT/ACKNACK state handling on the shared user socket. A reliable publisher
can communicate with both reliable and best-effort subscriptions, while a
best-effort publisher requires a best-effort subscription. Service/action
callbacks are not part of this node API.

`RosNode::new` still accepts a participant configured by the caller. The
existing `create_publisher` and `create_subscription` methods remain available
for custom codecs and explicit wire metadata.

Each best-effort reader retains duplicate-detection history for the latest 256
sequence numbers. It can reassemble at most four incomplete samples with a
combined payload size of 16 MiB (plus fragment metadata). Oversized fragmented
samples are dropped before allocation. When the budget is exhausted, newer
samples replace the oldest incomplete samples; samples outside the receive
window and duplicate samples are discarded.

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
