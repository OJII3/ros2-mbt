#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
server_script="$repo_root/scripts/ros2_parameter_server.py"
tmp_dir=$(mktemp -d)
server_log="$tmp_dir/parameter-server.log"
client_log="$tmp_dir/moonbit-parameter-client.log"
server_pid=""
server_grouped=0
client_pid=""
client_grouped=0

cleanup() {
  local exit_status=$?
  trap - EXIT INT TERM
  if [[ -n "$client_pid" ]]; then
    if [[ "$client_grouped" -eq 1 ]]; then
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

if ! python3 -c 'import rclpy; from rcl_interfaces.srv import GetParameters' \
  >/dev/null 2>&1; then
  echo "Python ROS 2 environment unavailable; run this script with nix develop .#ros2" >&2
  exit 127
fi

if command -v setsid >/dev/null 2>&1; then
  setsid python3 -u "$server_script" >"$server_log" 2>&1 &
  server_grouped=1
else
  python3 -u "$server_script" >"$server_log" 2>&1 &
fi
server_pid=$!

ready=0
for _ in {1..100}; do
  if grep -Fq GET_PARAMETERS_SERVER_READY "$server_log"; then
    ready=1
    break
  fi
  if ! kill -0 "$server_pid" 2>/dev/null; then
    break
  fi
  sleep 0.1
done
if [[ "$ready" -ne 1 ]]; then
  echo "GetParameters test server did not become ready" >&2
  exit 1
fi

if [[ -n "${ROS_DISTRO:-}" || -n "${IN_NIX_SHELL:-}" ]]; then
  moon_command=(moon run examples/parameter_client)
else
  moon_command=(nix develop --command moon run examples/parameter_client)
fi
if command -v setsid >/dev/null 2>&1; then
  setsid "${moon_command[@]}" >"$client_log" 2>&1 &
  client_grouped=1
else
  "${moon_command[@]}" >"$client_log" 2>&1 &
fi
client_pid=$!

client_finished=0
for _ in {1..300}; do
  if ! kill -0 "$client_pid" 2>/dev/null; then
    client_finished=1
    break
  fi
  sleep 0.2
done
if [[ "$client_finished" -ne 1 ]]; then
  echo "MoonBit GetParameters client timed out after 60 seconds" >&2
  exit 1
fi

client_status=0
if wait "$client_pid"; then
  client_status=0
else
  client_status=$?
fi
if [[ "$client_status" -ne 0 ]]; then
  echo "MoonBit GetParameters client failed (status $client_status)" >&2
  exit 1
fi
if [[ "$client_grouped" -eq 1 ]]; then
  kill -TERM -- "-$client_pid" 2>/dev/null || true
fi
client_pid=""
if ! grep -Fq 'SetParameters answer: true' "$client_log" || \
  ! grep -Fq 'GetParameters answer: 99' "$client_log"; then
  echo "MoonBit client did not set and read back the expected parameter" >&2
  exit 1
fi

echo "ROS 2 SetParameters/GetParameters interoperability passed."
