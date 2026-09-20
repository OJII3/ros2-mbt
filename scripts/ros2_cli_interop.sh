#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
source /opt/ros/jazzy/setup.bash

tmp_dir=$(mktemp -d)
echo_log="$tmp_dir/topic-echo.log"
talker_log="$tmp_dir/moonbit-talker.log"
listener_log="$tmp_dir/moonbit-listener.log"
publisher_log="$tmp_dir/topic-pub.log"
moon_service_log="$tmp_dir/moonbit-service-server.log"
service_call_log="$tmp_dir/ros2-service-call.log"
ros_service_log="$tmp_dir/ros2-service-server.log"
moon_client_log="$tmp_dir/moonbit-service-client.log"
echo_pid=""
talker_pid=""
listener_pid=""
moon_service_pid=""
ros_service_pid=""
moon_client_pid=""

cleanup() {
  local exit_status=$?
  if [[ -n "$echo_pid" ]]; then
    kill "$echo_pid" 2>/dev/null || true
    wait "$echo_pid" 2>/dev/null || true
  fi
  if [[ -n "$talker_pid" ]]; then
    kill "$talker_pid" 2>/dev/null || true
    wait "$talker_pid" 2>/dev/null || true
  fi
  if [[ -n "$listener_pid" ]]; then
    kill "$listener_pid" 2>/dev/null || true
    wait "$listener_pid" 2>/dev/null || true
  fi
  if [[ -n "$moon_service_pid" ]]; then
    kill "$moon_service_pid" 2>/dev/null || true
    wait "$moon_service_pid" 2>/dev/null || true
  fi
  if [[ -n "$ros_service_pid" ]]; then
    kill "$ros_service_pid" 2>/dev/null || true
    wait "$ros_service_pid" 2>/dev/null || true
  fi
  if [[ -n "$moon_client_pid" ]]; then
    kill "$moon_client_pid" 2>/dev/null || true
    wait "$moon_client_pid" 2>/dev/null || true
  fi
  if [[ $exit_status -ne 0 ]]; then
    cat "$talker_log" "$echo_log" "$listener_log" "$publisher_log" \
      "$moon_service_log" "$service_call_log" "$ros_service_log" \
      "$moon_client_log" 2>/dev/null || true
  fi
  rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

wait_for_node() {
  local node_name="$1"
  local process_pid="$2"
  for _ in {1..20}; do
    local nodes
    nodes=$(timeout 3s ros2 node list --spin-time 0.25 2>/dev/null || true)
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

timeout --foreground 45s ros2 topic echo /chatter std_msgs/msg/String --once \
  >"$echo_log" 2>&1 &
echo_pid=$!
timeout --foreground 45s nix develop --command moon run examples/talker \
  >"$talker_log" 2>&1 &
talker_pid=$!

wait_for_node "/demo/moon_talker" "$talker_pid"

wait "$talker_pid"
talker_pid=""
wait "$echo_pid"
echo_pid=""

if ! grep -Fq "hello from MoonBit #" "$echo_log"; then
  echo "ROS 2 CLI did not receive a MoonBit String sample"
  exit 1
fi

timeout --foreground 45s nix develop --command moon run examples/listener \
  >"$listener_log" 2>&1 &
listener_pid=$!

wait_for_node "/demo/moon_listener" "$listener_pid"

timeout --foreground 45s ros2 topic pub --times 5 --rate 10 \
  /chatter std_msgs/msg/String "{data: 'hello from ROS 2'}" \
  >"$publisher_log" 2>&1
wait "$listener_pid"
listener_pid=""

received_count=$(grep -Fxc "hello from ROS 2" "$listener_log" || true)
if [[ "$received_count" -ne 5 ]]; then
  echo "MoonBit listener received $received_count of 5 ROS 2 String samples"
  exit 1
fi

timeout --foreground 45s nix develop --command moon run examples/service_server \
  >"$moon_service_log" 2>&1 &
moon_service_pid=$!
wait_for_node "/demo/moon_add_two_ints_server" "$moon_service_pid"
timeout --foreground 45s ros2 service call /add_two_ints \
  example_interfaces/srv/AddTwoInts "{a: 2, b: 3}" \
  >"$service_call_log" 2>&1
wait "$moon_service_pid"
moon_service_pid=""
if ! grep -Fq "sum: 5" "$service_call_log" || \
  ! grep -Fq "served AddTwoInts request" "$moon_service_log"; then
  echo "ROS 2 CLI service call did not complete with the expected sum"
  exit 1
fi

ros2 run demo_nodes_cpp add_two_ints_server >"$ros_service_log" 2>&1 &
ros_service_pid=$!
wait_for_node "/add_two_ints_server" "$ros_service_pid"
timeout --foreground 45s nix develop --command moon run examples/service_client \
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
