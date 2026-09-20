#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
server_script="$repo_root/scripts/ros2_fibonacci_action_server.py"
tmp_dir=$(mktemp -d)
server_log="$tmp_dir/fibonacci-action-server.log"
client_log="$tmp_dir/moonbit-action-client.log"
server_pid=""
server_grouped=0
client_pid=""

cleanup() {
  local exit_status=$?
  trap - EXIT INT TERM
  if [[ -n "$client_pid" ]]; then
    if [[ "$server_grouped" -eq 1 ]]; then
      kill -TERM -- "-$client_pid" 2>/dev/null || true
    else
      kill -TERM "$client_pid" 2>/dev/null || true
    fi
    wait "$client_pid" 2>/dev/null || true
  fi
  if [[ -n "$server_pid" ]]; then
    if [[ "$server_grouped" -eq 1 ]]; then
      kill -TERM -- "-$server_pid" 2>/dev/null || true
    else
      kill -TERM "$server_pid" 2>/dev/null || true
    fi
    wait "$server_pid" 2>/dev/null || true
  fi
  if [[ "$exit_status" -ne 0 ]]; then
    for log in "$server_log" "$client_log"; do
      if [[ -s "$log" ]]; then
        printf '\n--- %s ---\n' "$log" >&2
        cat "$log" >&2
      fi
    done
  fi
  rm -rf -- "$tmp_dir"
  exit "$exit_status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if ! command -v python3 >/dev/null 2>&1 || \
  ! python3 -c 'import rclpy; from example_interfaces.action import Fibonacci' \
    >/dev/null 2>&1; then
  echo "Python ROS 2 Jazzy environment unavailable; enter nix develop .#ros2 or source a ROS 2 setup first" >&2
  exit 127
fi

start_in_process_group() {
  if command -v setsid >/dev/null 2>&1; then
    setsid "$@" &
    server_grouped=1
  else
    "$@" &
    server_grouped=0
  fi
  server_pid=$!
}

start_in_process_group python3 -u "$server_script" >"$server_log" 2>&1

ready=0
for _ in {1..100}; do
  if grep -Fq FIBONACCI_ACTION_SERVER_READY "$server_log"; then
    ready=1
    break
  fi
  if ! kill -0 "$server_pid" 2>/dev/null; then
    break
  fi
  sleep 0.1
done
if [[ "$ready" -ne 1 ]]; then
  echo "Fibonacci action server did not become ready" >&2
  exit 1
fi

if [[ -n "${ROS_DISTRO:-}" || -n "${IN_NIX_SHELL:-}" ]]; then
  moon_command=(moon run examples/action_client)
else
  moon_command=(nix develop --command moon run examples/action_client)
fi

run_client() {
  local mode="$1"
  local -a client_command=("${moon_command[@]}")
  client_log="$tmp_dir/moonbit-action-$mode.log"
  if [[ "$mode" == "canceled" ]]; then
    client_command=(env ROS2_MBT_CANCEL_GOAL=1 "${moon_command[@]}")
  fi

  if command -v setsid >/dev/null 2>&1; then
    setsid "${client_command[@]}" >"$client_log" 2>&1 &
    client_pid=$!
  else
    "${client_command[@]}" >"$client_log" 2>&1 &
    client_pid=$!
  fi

  local client_finished=0
  for _ in {1..300}; do
    if ! kill -0 "$client_pid" 2>/dev/null; then
      client_finished=1
      break
    fi
    sleep 0.2
  done
  if [[ "$client_finished" -ne 1 ]]; then
    echo "MoonBit Fibonacci $mode client timed out after 60 seconds" >&2
    exit 1
  fi

  local client_status=0
  if wait "$client_pid"; then
    client_status=0
  else
    client_status=$?
  fi
  if [[ "$client_status" -ne 0 ]]; then
    echo "MoonBit Fibonacci $mode client failed (status $client_status)" >&2
    exit 1
  fi
  if [[ "$server_grouped" -eq 1 ]]; then
    kill -TERM -- "-$client_pid" 2>/dev/null || true
  fi
  client_pid=""

  if ! grep -Fq 'Fibonacci goal accepted: true' "$client_log"; then
    echo "MoonBit $mode client output did not indicate goal acceptance" >&2
    exit 1
  fi
  if [[ "$mode" == "succeeded" ]]; then
    if ! grep -Fq 'Fibonacci result status: 4' "$client_log"; then
      echo "MoonBit client did not receive a succeeded result status" >&2
      exit 1
    fi
    compact_client_output=$(tr -d '[:space:]' <"$client_log")
    if [[ "$compact_client_output" != *'Fibonacciresult:'*'[0,1,1,2,3,5]'* ]]; then
      echo "MoonBit client did not receive the expected Fibonacci sequence" >&2
      exit 1
    fi
  else
    if ! grep -Fq 'Fibonacci cancel return code: 0' "$client_log"; then
      echo "MoonBit client did not cancel the Fibonacci goal" >&2
      exit 1
    fi
    if ! grep -Fq 'Fibonacci result status: 5' "$client_log"; then
      echo "MoonBit client did not receive a canceled result status" >&2
      exit 1
    fi
  fi
}

run_client succeeded
run_client canceled

echo "ROS 2 Fibonacci action success and cancellation interoperability passed."
