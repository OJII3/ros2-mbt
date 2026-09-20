#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# Keep reversed startup-order cases separate from the first participant leases.
base_ros_domain_id=${ROS_DOMAIN_ID:-0}
startup_order_ros_domain_id=$(((base_ros_domain_id + 1) % 233))

if ! command -v ros2 >/dev/null 2>&1 && [[ -f /opt/ros/jazzy/setup.bash ]]; then
  # shellcheck disable=SC1091
  source /opt/ros/jazzy/setup.bash
fi
if ! command -v ros2 >/dev/null 2>&1; then
  echo "ROS 2 CLI not found; use nix develop .#ros2 or source /opt/ros/jazzy/setup.bash" >&2
  exit 127
fi

tmp_dir=$(mktemp -d)
echo_log="$tmp_dir/topic-echo.log"
graph_observer_log="$tmp_dir/ros-graph-observer.log"
publisher_first_echo_log="$tmp_dir/publisher-first-topic-echo.log"
publisher_first_talker_log="$tmp_dir/publisher-first-moonbit-talker.log"
talker_log="$tmp_dir/moonbit-talker.log"
listener_log="$tmp_dir/moonbit-listener.log"
publisher_log="$tmp_dir/topic-pub.log"
publisher_first_listener_log="$tmp_dir/publisher-first-moonbit-listener.log"
publisher_first_publisher_log="$tmp_dir/publisher-first-topic-pub.log"
wstring_echo_log="$tmp_dir/wstring-topic-echo.log"
wstring_talker_log="$tmp_dir/moonbit-wstring-talker.log"
wstring_listener_log="$tmp_dir/moonbit-wstring-listener.log"
wstring_publisher_log="$tmp_dir/wstring-topic-pub.log"
moon_service_log="$tmp_dir/moonbit-service-server.log"
service_call_log="$tmp_dir/ros2-service-call.log"
ros_service_log="$tmp_dir/ros2-service-server.log"
moon_client_log="$tmp_dir/moonbit-service-client.log"
echo_pid=""
graph_observer_pid=""
talker_pid=""
listener_pid=""
publisher_pid=""
moon_service_pid=""
ros_service_pid=""
moon_client_pid=""

cleanup() {
  local exit_status=$?
  if [[ -n "$echo_pid" ]]; then
    kill -- "-$echo_pid" 2>/dev/null || true
    wait "$echo_pid" 2>/dev/null || true
  fi
  if [[ -n "$graph_observer_pid" ]]; then
    kill -- "-$graph_observer_pid" 2>/dev/null || true
    wait "$graph_observer_pid" 2>/dev/null || true
  fi
  if [[ -n "$talker_pid" ]]; then
    kill -- "-$talker_pid" 2>/dev/null || true
    wait "$talker_pid" 2>/dev/null || true
  fi
  if [[ -n "$listener_pid" ]]; then
    kill -- "-$listener_pid" 2>/dev/null || true
    wait "$listener_pid" 2>/dev/null || true
  fi
  if [[ -n "$publisher_pid" ]]; then
    kill -- "-$publisher_pid" 2>/dev/null || true
    wait "$publisher_pid" 2>/dev/null || true
  fi
  if [[ -n "$moon_service_pid" ]]; then
    kill -- "-$moon_service_pid" 2>/dev/null || true
    wait "$moon_service_pid" 2>/dev/null || true
  fi
  if [[ -n "$ros_service_pid" ]]; then
    kill -- "-$ros_service_pid" 2>/dev/null || true
    wait "$ros_service_pid" 2>/dev/null || true
  fi
  if [[ -n "$moon_client_pid" ]]; then
    kill -- "-$moon_client_pid" 2>/dev/null || true
    wait "$moon_client_pid" 2>/dev/null || true
  fi
  if [[ $exit_status -ne 0 ]]; then
    cat "$talker_log" "$echo_log" "$graph_observer_log" \
      "$listener_log" "$publisher_log" "$publisher_first_echo_log" \
      "$publisher_first_talker_log" "$publisher_first_listener_log" \
      "$publisher_first_publisher_log" \
      "$wstring_talker_log" "$wstring_echo_log" \
      "$wstring_listener_log" "$wstring_publisher_log" \
      "$moon_service_log" "$service_call_log" "$ros_service_log" \
      "$moon_client_log" 2>/dev/null || true
  fi
  rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

wait_for_node() {
  local node_name="$1"
  local process_pid="$2"
  local deadline=$((SECONDS + 45))
  while ((SECONDS < deadline)); do
    local nodes
    nodes=$(timeout --kill-after=1s 3s ros2 node list --spin-time 0.25 2>/dev/null || true)
    if grep -Fxq "$node_name" <<<"$nodes"; then
      return 0
    fi
    if [[ -n "$process_pid" ]] && ! kill -0 "$process_pid" 2>/dev/null; then
      break
    fi
    sleep 0.5
  done
  echo "ROS 2 CLI did not discover $node_name"
  return 1
}

wait_for_node_endpoint() {
  local node_name="$1"
  local endpoint_section="$2"
  local endpoint_name="$3"
  for _ in {1..20}; do
    local node_info
    node_info=$(timeout --kill-after=1s 3s ros2 node info "$node_name" 2>/dev/null || true)
    if awk -v section="  $endpoint_section:" -v endpoint="    $endpoint_name:" '
      $0 == section { in_section = 1; next }
      /^  [[:alpha:] ]+:$/ { in_section = 0 }
      in_section && index($0, endpoint) == 1 { found = 1 }
      END { exit !found }
    ' <<<"$node_info"; then
      return 0
    fi
    sleep 0.5
  done
  echo "ROS 2 CLI did not discover $endpoint_section endpoint $endpoint_name on $node_name"
  return 1
}

wait_for_ros_endpoint() {
  local node_name="$1"
  local process_pid="$2"
  local endpoint_section="$3"
  local endpoint_name="$4"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    sleep 1
    if [[ -n "$process_pid" ]] && ! kill -0 "$process_pid" 2>/dev/null; then
      echo "ROS 2 test process exited before checking $endpoint_name"
      return 1
    fi
    return 0
  fi
  wait_for_node "$node_name" "$process_pid"
  wait_for_node_endpoint "$node_name" "$endpoint_section" "$endpoint_name"
}

timeout --kill-after=2s 45s ros2 topic echo /chatter std_msgs/msg/String --once \
  >"$echo_log" 2>&1 &
echo_pid=$!
if [[ "$(uname -s)" == "Linux" || "${ROS2_MBT_VERIFY_ROS_GRAPH:-0}" == "1" ]]; then
  timeout --kill-after=2s 45s python3 -u \
    "$script_dir/ros2_graph_interop_observer.py" >"$graph_observer_log" 2>&1 &
  graph_observer_pid=$!
fi
timeout --kill-after=2s 45s nix develop --command moon run examples/talker \
  >"$talker_log" 2>&1 &
talker_pid=$!

wait_for_ros_endpoint "/demo/moon_talker" "$talker_pid" "Publishers" "/chatter"

wait "$talker_pid"
talker_pid=""
wait "$echo_pid"
echo_pid=""
if ! grep -Fq "hello from MoonBit #" "$echo_log"; then
  echo "ROS 2 CLI did not receive a MoonBit String sample"
  exit 1
fi
if [[ -n "$graph_observer_pid" ]]; then
  wait "$graph_observer_pid"
  graph_observer_pid=""
  if ! grep -Fq "ROS_DISCOVERY_INFO_MATCHED /demo/moon_talker /chatter" \
    "$graph_observer_log"; then
    echo "ROS 2 graph observer did not validate MoonBit participant metadata"
    exit 1
  fi
fi

# A publisher that starts before its subscriber must keep announcing until the
# later subscriber is discovered, rather than relying on startup order.
ROS_DOMAIN_ID="$startup_order_ros_domain_id"
export ROS_DOMAIN_ID
timeout --kill-after=2s 45s nix develop --command moon run examples/talker \
  >"$publisher_first_talker_log" 2>&1 &
talker_pid=$!
sleep 1
if ! kill -0 "$talker_pid" 2>/dev/null; then
  echo "MoonBit talker exited before the later ROS 2 subscriber started"
  exit 1
fi
timeout --kill-after=2s 45s ros2 topic echo /chatter std_msgs/msg/String --once \
  >"$publisher_first_echo_log" 2>&1 &
echo_pid=$!
wait_for_ros_endpoint "/demo/moon_talker" "$talker_pid" "Publishers" "/chatter"
wait "$talker_pid"
talker_pid=""
wait "$echo_pid"
echo_pid=""
if ! grep -Fq "hello from MoonBit #" "$publisher_first_echo_log"; then
  echo "ROS 2 CLI did not receive a sample from a publisher started first"
  exit 1
fi
ROS_DOMAIN_ID="$base_ros_domain_id"
export ROS_DOMAIN_ID

timeout --kill-after=2s 45s nix develop --command moon run examples/listener \
  >"$listener_log" 2>&1 &
listener_pid=$!

wait_for_ros_endpoint "/demo/moon_listener" "$listener_pid" "Subscribers" "/chatter"

timeout --kill-after=2s 45s ros2 topic pub --times 5 --rate 10 \
  /chatter std_msgs/msg/String "{data: 'hello from ROS 2'}" \
  >"$publisher_log" 2>&1
wait "$listener_pid"
listener_pid=""

received_count=$(grep -Fxc "hello from ROS 2" "$listener_log" || true)
if [[ "$received_count" -ne 5 ]]; then
  echo "MoonBit listener received $received_count of 5 ROS 2 String samples"
  exit 1
fi

# Keep the ROS 2 publisher alive while waiting for a MoonBit listener that
# starts later, then verify all post-match samples arrive.
ROS_DOMAIN_ID="$startup_order_ros_domain_id"
export ROS_DOMAIN_ID
timeout --kill-after=2s 45s ros2 topic pub --times 5 --rate 10 \
  --wait-matching-subscriptions 1 /chatter std_msgs/msg/String \
  "{data: 'hello from ROS 2'}" >"$publisher_first_publisher_log" 2>&1 &
publisher_pid=$!
sleep 1
if ! kill -0 "$publisher_pid" 2>/dev/null; then
  echo "ROS 2 publisher exited before the later MoonBit subscriber started"
  exit 1
fi
timeout --kill-after=2s 45s nix develop --command moon run examples/listener \
  >"$publisher_first_listener_log" 2>&1 &
listener_pid=$!
wait_for_ros_endpoint "/demo/moon_listener" "$listener_pid" "Subscribers" "/chatter"
wait "$publisher_pid"
publisher_pid=""
wait "$listener_pid"
listener_pid=""
received_count=$(grep -Fxc "hello from ROS 2" "$publisher_first_listener_log" || true)
if [[ "$received_count" -ne 5 ]]; then
  echo "MoonBit listener received $received_count of 5 publisher-first ROS 2 samples"
  exit 1
fi
ROS_DOMAIN_ID="$base_ros_domain_id"
export ROS_DOMAIN_ID

timeout --kill-after=2s 45s ros2 topic echo /wide_chatter \
  example_interfaces/msg/WString --qos-reliability reliable --once \
  >"$wstring_echo_log" 2>&1 &
echo_pid=$!
timeout --kill-after=2s 45s nix develop --command moon run \
  examples/wstring_talker >"$wstring_talker_log" 2>&1 &
talker_pid=$!
wait_for_ros_endpoint "/demo/moon_wstring_talker" "$talker_pid" \
  "Publishers" "/wide_chatter"
wait "$talker_pid"
talker_pid=""
wait "$echo_pid"
echo_pid=""
if ! grep -Fq "wide こんにちは 🙂 #" "$wstring_echo_log"; then
  echo "ROS 2 CLI did not receive a MoonBit WString sample"
  exit 1
fi

timeout --kill-after=2s 45s nix develop --command moon run \
  examples/wstring_listener >"$wstring_listener_log" 2>&1 &
listener_pid=$!
wait_for_ros_endpoint "/demo/moon_wstring_listener" "$listener_pid" \
  "Subscribers" "/wide_chatter"
timeout --kill-after=2s 45s ros2 topic pub --times 5 --rate 10 \
  --qos-reliability reliable /wide_chatter example_interfaces/msg/WString \
  "{data: 'wide こんにちは 🙂'}" >"$wstring_publisher_log" 2>&1
wait "$listener_pid"
listener_pid=""

received_count=$(grep -Fxc "wide こんにちは 🙂" "$wstring_listener_log" || true)
if [[ "$received_count" -ne 5 ]]; then
  echo "MoonBit listener received $received_count of 5 ROS 2 WString samples"
  exit 1
fi

timeout --kill-after=2s 45s nix develop --command moon run examples/service_server \
  >"$moon_service_log" 2>&1 &
moon_service_pid=$!
wait_for_ros_endpoint "/demo/moon_add_two_ints_server" "$moon_service_pid" \
  "Service Servers" "/add_two_ints"
timeout --kill-after=2s 45s ros2 service call /add_two_ints \
  example_interfaces/srv/AddTwoInts "{a: 2, b: 3}" \
  >"$service_call_log" 2>&1
wait "$moon_service_pid"
moon_service_pid=""
if ! grep -Eq "sum[=:][[:space:]]*5" "$service_call_log" || \
  ! grep -Fq "served AddTwoInts request" "$moon_service_log"; then
  echo "ROS 2 CLI service call did not complete with the expected sum"
  exit 1
fi

ros2 run demo_nodes_cpp add_two_ints_server >"$ros_service_log" 2>&1 &
ros_service_pid=$!
wait_for_ros_endpoint "/add_two_ints_server" "$ros_service_pid" \
  "Service Servers" "/add_two_ints"
timeout --kill-after=2s 45s nix develop --command moon run examples/service_client \
  >"$moon_client_log" 2>&1 &
moon_client_pid=$!
wait "$moon_client_pid"
moon_client_pid=""
if ! grep -Fq "AddTwoInts result: 5" "$moon_client_log"; then
  echo "MoonBit service client did not receive the expected ROS 2 response"
  exit 1
fi
kill "$ros_service_pid" 2>/dev/null || true
wait "$ros_service_pid" 2>/dev/null || true
ros_service_pid=""
