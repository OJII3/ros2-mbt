#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
source /opt/ros/jazzy/setup.bash

tmp_dir=$(mktemp -d)
echo_log="$tmp_dir/topic-echo.log"
talker_log="$tmp_dir/moonbit-talker.log"
listener_log="$tmp_dir/moonbit-listener.log"
publisher_log="$tmp_dir/topic-pub.log"
echo_pid=""
talker_pid=""
listener_pid=""

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
  if [[ $exit_status -ne 0 ]]; then
    cat "$talker_log" "$echo_log" "$listener_log" "$publisher_log" 2>/dev/null || true
  fi
  rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

timeout --foreground 45s ros2 topic echo /chatter std_msgs/msg/String --once \
  >"$echo_log" 2>&1 &
echo_pid=$!
timeout --foreground 45s nix develop --command moon run examples/talker \
  >"$talker_log" 2>&1 &
talker_pid=$!

graph_seen=0
for _ in {1..20}; do
  nodes=$(timeout 3s ros2 node list --spin-time 0.25 2>/dev/null || true)
  if grep -Fxq "/demo/moon_talker" <<<"$nodes"; then
    graph_seen=1
    break
  fi
  if ! kill -0 "$talker_pid" 2>/dev/null; then
    break
  fi
  sleep 0.5
done

if [[ $graph_seen -ne 1 ]]; then
  echo "ROS 2 CLI did not discover /demo/moon_talker"
  exit 1
fi

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

graph_seen=0
for _ in {1..20}; do
  nodes=$(timeout 3s ros2 node list --spin-time 0.25 2>/dev/null || true)
  if grep -Fxq "/demo/moon_listener" <<<"$nodes"; then
    graph_seen=1
    break
  fi
  if ! kill -0 "$listener_pid" 2>/dev/null; then
    break
  fi
  sleep 0.5
done

if [[ $graph_seen -ne 1 ]]; then
  echo "ROS 2 CLI did not discover /demo/moon_listener"
  exit 1
fi

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
