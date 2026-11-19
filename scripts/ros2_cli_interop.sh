#!/usr/bin/env bash
# scenario_directory is assigned inside each scenario subshell. ShellCheck
# cannot see that the scenario functions run in the same subshell.
# shellcheck disable=SC2030,SC2031
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if ! command -v ros2 >/dev/null 2>&1 && [[ -f /opt/ros/jazzy/setup.bash ]]; then
  # shellcheck disable=SC1091
  source /opt/ros/jazzy/setup.bash
fi
if ! command -v ros2 >/dev/null 2>&1; then
  echo "ROS 2 CLI not found; use nix develop .#ros2 or source /opt/ros/jazzy/setup.bash" >&2
  exit 127
fi
if command -v moon >/dev/null 2>&1; then
  moon_build_command=(moon build --release --target native)
else
  moon_build_command=(nix develop --command moon build --release --target native)
fi

# Advertise the interface that carries multicast. The container runner sets
# these explicitly; on a Linux host, fall back to the multicast route so the
# MoonBit participants and the ROS 2 processes use the same interface.
if [[ -z "${ROS2_MBT_IP:-}" && -z "${ROS2_MBT_MULTICAST_IP:-}" ]] &&
  command -v ip >/dev/null 2>&1; then
  host_ip=$(ip -4 route get 239.255.0.1 2>/dev/null | awk '
    {for (i = 1; i <= NF; i++) if ($i == "src") {print $(i + 1); exit}}
  ' || true)
  if [[ -n "$host_ip" ]]; then
    export ROS2_MBT_IP="$host_ip"
    export ROS2_MBT_MULTICAST_IP="$host_ip"
  fi
elif [[ -n "${ROS2_MBT_IP:-}" && -z "${ROS2_MBT_MULTICAST_IP:-}" ]]; then
  export ROS2_MBT_MULTICAST_IP="$ROS2_MBT_IP"
fi

# Every scenario owns a ROS domain, so independent startup orders and
# discovery leases cannot leak into one another. Scenarios run in waves of at
# most ROS2_MBT_E2E_JOBS and each wave is joined before the next starts.
# Scenarios use base .. base + 10. Override with ROS_DOMAIN_ID to move the
# whole range away from other ROS 2 traffic on the host.
base_ros_domain_id=${ROS_DOMAIN_ID:-42}
scenario_timeout_seconds=${ROS2_MBT_E2E_TIMEOUT_SECONDS:-45}
expected_hello_prefix="hello from MoonBit #"
verify_ros_graph=0
if [[ "$(uname -s)" == "Linux" || "${ROS2_MBT_VERIFY_ROS_GRAPH:-0}" == "1" ]]; then
  verify_ros_graph=1
fi

use_setsid=0
if command -v setsid >/dev/null 2>&1; then
  use_setsid=1
fi

max_parallel_scenarios=${ROS2_MBT_E2E_JOBS:-4}
if ! [[ "$max_parallel_scenarios" =~ ^[1-9][0-9]*$ ]]; then
  echo "ROS2_MBT_E2E_JOBS must be a positive integer" >&2
  exit 2
fi

tmp_dir=$(mktemp -d)
scenario_pids=()
scenario_names=()
scenario_domains=()
scenario_dirs=()
queued_names=()
queued_functions=()
queued_domains=()
scenario_count=0
failed=0

# Send TERM first so ROS nodes can shut down, then KILL the process group.
# `ros2 run` starts the node as a child that can outlive its CLI wrapper, so
# killing only the wrapper leaves participants bound to the scenario's ports.
terminate_process() {
  local process_pid="$1"
  local process_grouped="${2:-0}"
  local target="$process_pid"
  if [[ "$process_grouped" -eq 1 ]]; then
    target="-$process_pid"
  fi
  if ! kill -0 -- "$target" 2>/dev/null; then
    return 0
  fi
  kill -TERM -- "$target" 2>/dev/null || true
  sleep 0.1
  kill -KILL -- "$target" 2>/dev/null || true
}

cleanup() {
  local exit_status=$?
  trap - EXIT INT TERM
  local process_file
  for process_file in "$tmp_dir"/*/processes; do
    [[ -f "$process_file" ]] || continue
    while read -r process_pid process_grouped; do
      [[ -n "$process_pid" ]] || continue
      terminate_process "$process_pid" "${process_grouped:-0}"
    done <"$process_file"
  done
  for scenario_pid in "${scenario_pids[@]}"; do
    kill -TERM "$scenario_pid" 2>/dev/null || true
  done
  sleep 0.1
  for scenario_pid in "${scenario_pids[@]}"; do
    kill -KILL "$scenario_pid" 2>/dev/null || true
    wait "$scenario_pid" 2>/dev/null || true
  done
  rm -rf -- "$tmp_dir"
  exit "$exit_status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

start_scenario() {
  local name="$1"
  shift
  local domain_id=$(((base_ros_domain_id + scenario_count) % 233))
  scenario_count=$((scenario_count + 1))
  if [[ -n "${ROS2_MBT_E2E_SCENARIOS:-}" &&
    ",${ROS2_MBT_E2E_SCENARIOS}," != *",$name,"* ]]; then
    return 0
  fi
  queued_names+=("$name")
  queued_functions+=("$1")
  queued_domains+=("$domain_id")
}

launch_scenario() {
  local name="$1"
  local domain_id="$2"
  local scenario_function="$3"
  local scenario_dir="$tmp_dir/$name"
  mkdir -p "$scenario_dir"
  (
    export ROS_DOMAIN_ID="$domain_id"
    scenario_directory="$scenario_dir"
    "$scenario_function"
  ) >"$scenario_dir/run.log" 2>&1 &
  scenario_pids+=("$!")
  scenario_names+=("$name")
  scenario_domains+=("$domain_id")
  scenario_dirs+=("$scenario_dir")
}

wait_for_scenarios() {
  local index
  for index in "${!scenario_pids[@]}"; do
    if ! wait "${scenario_pids[$index]}"; then
      failed=1
      printf '\n=== scenario %s failed (ROS_DOMAIN_ID=%s) ===\n' \
        "${scenario_names[$index]}" "${scenario_domains[$index]}" >&2
      if [[ -s "${scenario_dirs[$index]}/run.log" ]]; then
        cat "${scenario_dirs[$index]}/run.log" >&2
      fi
    fi
  done
  scenario_pids=()
  scenario_names=()
  scenario_domains=()
  scenario_dirs=()
}

run_queued_scenarios() {
  local index=0
  local wave_end
  while ((index < ${#queued_names[@]})); do
    wave_end=$((index + max_parallel_scenarios))
    if ((wave_end > ${#queued_names[@]})); then
      wave_end=${#queued_names[@]}
    fi
    while ((index < wave_end)); do
      launch_scenario "${queued_names[$index]}" "${queued_domains[$index]}" \
        "${queued_functions[$index]}"
      index=$((index + 1))
    done
    wait_for_scenarios
  done
}

bg_pids=()
bg_grouped=()
last_bg_pid=""
last_bg_grouped=0

scenario_cleanup() {
  local exit_status=$?
  trap - EXIT INT TERM
  local process_index
  for process_index in "${!bg_pids[@]}"; do
    terminate_process "${bg_pids[$process_index]}" \
      "${bg_grouped[$process_index]:-0}"
  done
  for process_pid in "${bg_pids[@]}"; do
    wait "$process_pid" 2>/dev/null || true
  done
  if [[ "$exit_status" -ne 0 ]]; then
    local log_file
    for log_file in "$scenario_directory"/*.log; do
      [[ -f "$log_file" ]] || continue
      [[ "$log_file" == "$scenario_directory/run.log" ]] && continue
      printf '\n--- %s ---\n' "$log_file"
      cat "$log_file"
    done
  fi
  exit "$exit_status"
}

begin_scenario() {
  bg_pids=()
  bg_grouped=()
  trap scenario_cleanup EXIT INT TERM
}

start_bg() {
  local log_file="$1"
  shift
  local process_grouped=0
  if [[ "$use_setsid" -eq 1 ]]; then
    setsid timeout --kill-after=2s "${scenario_timeout_seconds}s" "$@" \
      >"$log_file" 2>&1 &
    process_grouped=1
  else
    timeout --kill-after=2s "${scenario_timeout_seconds}s" "$@" \
      >"$log_file" 2>&1 &
  fi
  last_bg_pid=$!
  last_bg_grouped=$process_grouped
  bg_pids+=("$last_bg_pid")
  bg_grouped+=("$last_bg_grouped")
  printf '%s %s\n' "$last_bg_pid" "$last_bg_grouped" \
    >>"$scenario_directory/processes"
}

stop_bg() {
  local process_pid="$1"
  if [[ -z "$process_pid" ]]; then
    return 0
  fi
  local process_index
  local process_grouped=0
  for process_index in "${!bg_pids[@]}"; do
    if [[ "${bg_pids[$process_index]}" == "$process_pid" ]]; then
      process_grouped="${bg_grouped[$process_index]:-0}"
      break
    fi
  done
  terminate_process "$process_pid" "$process_grouped"
  wait "$process_pid" 2>/dev/null || true
}

wait_for_marker() {
  local log_file="$1"
  local marker="$2"
  local process_pid="${3:-}"
  local deadline=$((SECONDS + ${4:-$scenario_timeout_seconds}))
  while ((SECONDS < deadline)); do
    if [[ -f "$log_file" ]] && grep -Fq -- "$marker" "$log_file"; then
      return 0
    fi
    if [[ -n "$process_pid" ]] && ! kill -0 "$process_pid" 2>/dev/null; then
      if [[ -f "$log_file" ]] && grep -Fq -- "$marker" "$log_file"; then
        return 0
      fi
      echo "process $process_pid exited before emitting marker: $marker" >&2
      return 1
    fi
    sleep 0.05
  done
  echo "timed out waiting for marker: $marker in $log_file" >&2
  return 1
}

assert_log_contains() {
  local log_file="$1"
  local expected="$2"
  local message="$3"
  if ! grep -Fq -- "$expected" "$log_file"; then
    echo "$message" >&2
    return 1
  fi
}

# A ROS 2 publisher endpoint must be discovered by two successive ros2-mbt CLI
# invocations that each start after the previous one exited.
run_topic_list() {
  begin_scenario
  local talker_log="$scenario_directory/ros2-topic-list-talker.log"
  start_bg "$talker_log" ros2 run demo_nodes_cpp talker
  local talker_pid=$last_bg_pid
  wait_for_marker "$talker_log" "Publishing:" "$talker_pid"

  # Wait until a ROS 2 participant can match the talker's topic endpoint.
  # Otherwise the bounded ros2-mbt discovery window can start before the
  # talker has announced /chatter and the CLI would legitimately see nothing.
  local readiness_log="$scenario_directory/topic-readiness-probe.log"
  start_bg "$readiness_log" python3 -u "$script_dir/ros2_topic_probe.py" \
    --topic /chatter --type string --expected-prefix "Hello World"
  local readiness_pid=$last_bg_pid
  wait_for_marker "$readiness_log" "PROBE_MATCHED " "$readiness_pid"
  wait "$readiness_pid"

  local list_log
  for list_log in "$scenario_directory/moonbit-topic-list-first.log" \
    "$scenario_directory/moonbit-topic-list-second.log"; do
    start_bg "$list_log" "$topic_list_executable" topic list -t \
      --spin-time-ms 5000
    wait "$last_bg_pid"
    assert_log_contains "$list_log" "/chatter [std_msgs/msg/String]" \
      "ros2-mbt topic list did not discover /chatter from the ROS 2 talker"
  done
  stop_bg "$talker_pid"
}

# A ROS 2 reliable subscription and the ROS graph must both observe a MoonBit
# talker. The graph observer is ready before the talker starts, so the test
# measures discovery instead of racing Python process startup.
run_moonbit_talker() {
  begin_scenario
  local probe_log="$scenario_directory/topic-probe.log"
  start_bg "$probe_log" python3 -u "$script_dir/ros2_topic_probe.py" \
    --topic /chatter --type string --expected-prefix "$expected_hello_prefix"
  local probe_pid=$last_bg_pid
  wait_for_marker "$probe_log" "PROBE_READY " "$probe_pid"

  local observer_pid=""
  local observer_log=""
  if [[ "$verify_ros_graph" -eq 1 ]]; then
    observer_log="$scenario_directory/ros-graph-observer.log"
    start_bg "$observer_log" env ROS2_MBT_GRAPH_TIMEOUT=20 \
      python3 -u "$script_dir/ros2_graph_interop_observer.py"
    observer_pid=$last_bg_pid
    wait_for_marker "$observer_log" "ROS_GRAPH_OBSERVER_READY" "$observer_pid"
  fi

  local talker_log="$scenario_directory/moonbit-talker.log"
  start_bg "$talker_log" "$talker_executable"
  local talker_pid=$last_bg_pid

  wait "$probe_pid"
  assert_log_contains "$probe_log" "PROBE_RECEIVED $expected_hello_prefix" \
    "ROS 2 subscriber probe did not receive a MoonBit String sample"
  wait "$talker_pid"
  if [[ -n "$observer_pid" ]]; then
    wait "$observer_pid"
    assert_log_contains "$observer_log" \
      "ROS_DISCOVERY_INFO_MATCHED /demo/moon_talker /chatter" \
      "ROS 2 graph observer did not validate MoonBit participant metadata"
  fi
}

# One ROS 2 publisher endpoint must deliver the same topic stream to two
# independently discovered subscriptions with different reliability.
run_two_subscribers() {
  begin_scenario
  local reliable_log="$scenario_directory/topic-probe.log"
  start_bg "$reliable_log" python3 -u "$script_dir/ros2_topic_probe.py" \
    --topic /chatter --type string --expected-prefix "$expected_hello_prefix"
  local reliable_pid=$last_bg_pid
  wait_for_marker "$reliable_log" "PROBE_READY " "$reliable_pid"

  local best_effort_log="$scenario_directory/topic-probe-best-effort.log"
  start_bg "$best_effort_log" python3 -u "$script_dir/ros2_topic_probe.py" \
    --topic /chatter --type string --reliability best_effort \
    --expected-prefix "$expected_hello_prefix"
  local best_effort_pid=$last_bg_pid
  wait_for_marker "$best_effort_log" "PROBE_READY " "$best_effort_pid"

  local talker_log="$scenario_directory/moonbit-talker.log"
  start_bg "$talker_log" "$talker_executable"
  local talker_pid=$last_bg_pid

  wait "$reliable_pid"
  wait "$best_effort_pid"
  wait "$talker_pid"
  assert_log_contains "$reliable_log" "PROBE_RECEIVED $expected_hello_prefix" \
    "The reliable ROS 2 subscriber probe did not receive a sample"
  assert_log_contains "$best_effort_log" \
    "PROBE_RECEIVED $expected_hello_prefix" \
    "The best-effort ROS 2 subscriber probe did not receive a sample"
}

# A publisher that starts before its subscribers must keep announcing until a
# later subscriber is discovered, rather than relying on startup order.
run_publisher_first() {
  begin_scenario
  local talker_log="$scenario_directory/moonbit-talker.log"
  start_bg "$talker_log" env ROS2_MBT_TALKER_PUBLISH_UNTIL_STOP=1 \
    "$talker_executable"
  local talker_pid=$last_bg_pid

  local first_log="$scenario_directory/topic-probe.log"
  start_bg "$first_log" python3 -u "$script_dir/ros2_topic_probe.py" \
    --topic /chatter --type string --expected-prefix "$expected_hello_prefix"
  local first_pid=$last_bg_pid
  wait_for_marker "$first_log" "PROBE_MATCHED " "$first_pid"

  local second_log="$scenario_directory/topic-probe-second-subscriber.log"
  start_bg "$second_log" python3 -u "$script_dir/ros2_topic_probe.py" \
    --topic /chatter --type string --reliability best_effort \
    --expected-prefix "$expected_hello_prefix"
  local second_pid=$last_bg_pid
  wait_for_marker "$second_log" "PROBE_MATCHED " "$second_pid"

  wait "$first_pid"
  wait "$second_pid"
  stop_bg "$talker_pid"
  assert_log_contains "$second_log" "PROBE_RECEIVED $expected_hello_prefix" \
    "A later ROS 2 subscriber probe did not receive a subsequent sample"
}

# A ROS 2 publisher waits for a MoonBit listener that starts later, then every
# post-match sample must arrive.
run_ros_publisher_to_listener() {
  begin_scenario
  local publisher_log="$scenario_directory/ros2-topic-pub.log"
  start_bg "$publisher_log" ros2 topic pub --times 5 --rate 10 \
    --wait-matching-subscriptions 1 /chatter std_msgs/msg/String \
    "{data: 'hello from ROS 2'}"
  local publisher_pid=$last_bg_pid
  wait_for_marker "$publisher_log" \
    "Waiting for at least 1 matching subscription" "$publisher_pid"

  local listener_log="$scenario_directory/moonbit-listener.log"
  start_bg "$listener_log" "$listener_executable"
  local listener_pid=$last_bg_pid

  wait "$publisher_pid"
  wait "$listener_pid"
  local received_count
  received_count=$(grep -Fxc "hello from ROS 2" "$listener_log" || true)
  if [[ "$received_count" -ne 5 ]]; then
    echo "MoonBit listener received $received_count of 5 ROS 2 String samples" >&2
    return 1
  fi
}

# The MoonBit WString talker must satisfy a ROS 2 WString subscription.
run_wstring_talker() {
  begin_scenario
  local probe_log="$scenario_directory/wstring-topic-probe.log"
  start_bg "$probe_log" python3 -u "$script_dir/ros2_topic_probe.py" \
    --topic /wide_chatter --type wstring \
    --expected-prefix "wide こんにちは 🙂 #"
  local probe_pid=$last_bg_pid
  wait_for_marker "$probe_log" "PROBE_READY " "$probe_pid"

  local talker_log="$scenario_directory/moonbit-wstring-talker.log"
  start_bg "$talker_log" "$wstring_talker_executable"
  local talker_pid=$last_bg_pid

  wait "$talker_pid"
  wait "$probe_pid"
  assert_log_contains "$probe_log" \
    "PROBE_RECEIVED wide こんにちは 🙂 #" \
    "ROS 2 subscriber probe did not receive a MoonBit WString sample"
}

# A ROS 2 WString publisher must satisfy a MoonBit WString subscription.
run_wstring_listener() {
  begin_scenario
  local listener_log="$scenario_directory/moonbit-wstring-listener.log"
  start_bg "$listener_log" "$wstring_listener_executable"
  local listener_pid=$last_bg_pid

  local publisher_log="$scenario_directory/wstring-topic-pub.log"
  start_bg "$publisher_log" ros2 topic pub --times 5 --rate 10 \
    --wait-matching-subscriptions 1 --qos-reliability reliable \
    /wide_chatter example_interfaces/msg/WString \
    "{data: 'wide こんにちは 🙂'}"
  local publisher_pid=$last_bg_pid

  wait "$publisher_pid"
  wait "$listener_pid"
  local received_count
  received_count=$(grep -Fxc "wide こんにちは 🙂" "$listener_log" || true)
  if [[ "$received_count" -ne 5 ]]; then
    echo "MoonBit listener received $received_count of 5 ROS 2 WString samples" >&2
    return 1
  fi
}

# The MoonBit service server must serve a ROS 2 CLI call and expose its ROS
# graph identity before the call.
run_moonbit_service_server() {
  begin_scenario
  local observer_log="$scenario_directory/ros-service-graph-observer.log"
  start_bg "$observer_log" python3 -u \
    "$script_dir/ros2_service_graph_interop_observer.py"
  local observer_pid=$last_bg_pid
  wait_for_marker "$observer_log" "ROS_GRAPH_OBSERVER_READY" "$observer_pid"

  local server_log="$scenario_directory/moonbit-service-server.log"
  start_bg "$server_log" "$service_server_executable"
  local server_pid=$last_bg_pid
  wait_for_marker "$server_log" "SERVICE_SERVER_READY" "$server_pid"
  wait_for_marker "$observer_log" \
    "ROS_DISCOVERY_INFO_MATCHED /demo/moon_add_two_ints_server" "$observer_pid"

  local call_log="$scenario_directory/ros2-service-call.log"
  start_bg "$call_log" ros2 service call /add_two_ints \
    example_interfaces/srv/AddTwoInts "{a: 2, b: 3}"
  wait "$last_bg_pid"
  wait "$server_pid"
  wait "$observer_pid"
  if ! grep -Eq "sum[=:][[:space:]]*5" "$call_log"; then
    echo "ROS 2 CLI service call did not complete with the expected sum" >&2
    return 1
  fi
  assert_log_contains "$server_log" "served AddTwoInts request" \
    "The MoonBit service server did not report a served request"
}

# A MoonBit service client must discover and call a ROS 2 service server.
run_ros_service_server() {
  begin_scenario
  local server_log="$scenario_directory/ros2-service-server.log"
  start_bg "$server_log" ros2 run demo_nodes_cpp add_two_ints_server
  local server_pid=$last_bg_pid

  local client_log="$scenario_directory/moonbit-service-client.log"
  start_bg "$client_log" "$service_client_executable"
  local client_pid=$last_bg_pid

  wait "$client_pid"
  stop_bg "$server_pid"
  assert_log_contains "$client_log" "AddTwoInts result: 5" \
    "MoonBit service client did not receive the expected ROS 2 response"
}

# Exercise the high-level node API, including its reliable ROS graph traffic.
run_node_talker() {
  begin_scenario
  local probe_log="$scenario_directory/node-interop-probe.log"
  start_bg "$probe_log" python3 -u \
    "$script_dir/ros2_node_interop_probe.py" "$node_talker_executable"
  wait "$last_bg_pid"
  assert_log_contains "$probe_log" \
    "ROS_NODE_API_MATCHED /demo/moon_node_talker /chatter" \
    "The high-level ROS node API did not publish or expose the expected graph"
}

# A MoonBit Image publisher must wait for the discovered subscriber, then stream
# the whole camera-sized set.
run_moonbit_image_talker() {
  begin_scenario
  local probe_log="$scenario_directory/image-probe.log"
  start_bg "$probe_log" python3 -u "$script_dir/ros2_image_probe.py" \
    --mode subscribe --topic /image --count 10
  local probe_pid=$last_bg_pid
  wait_for_marker "$probe_log" "IMAGE_PROBE_READY " "$probe_pid"

  local talker_log="$scenario_directory/moonbit-image-talker.log"
  start_bg "$talker_log" "$image_talker_executable"
  local talker_pid=$last_bg_pid

  wait "$talker_pid"
  wait "$probe_pid"
  assert_log_contains "$talker_log" "IMAGE_TALKER_DONE count=10 " \
    "The MoonBit image talker did not publish the expected stream"
  assert_log_contains "$probe_log" "IMAGE_STREAM_OK count=10 " \
    "The ROS 2 image probe did not receive the complete MoonBit stream"
}

# A ROS 2 camera-sized Image stream must satisfy a MoonBit Image subscription.
run_ros_image_publisher() {
  begin_scenario
  local listener_log="$scenario_directory/moonbit-image-listener.log"
  start_bg "$listener_log" "$image_listener_executable"
  local listener_pid=$last_bg_pid
  wait_for_marker "$listener_log" "IMAGE_LISTENER_READY " "$listener_pid"

  local publisher_log="$scenario_directory/ros2-image-publisher.log"
  start_bg "$publisher_log" python3 -u "$script_dir/ros2_image_probe.py" \
    --mode publish --topic /image --count 10
  local publisher_pid=$last_bg_pid

  wait "$publisher_pid"
  wait "$listener_pid"
  assert_log_contains "$publisher_log" "IMAGE_PUBLISHER_DONE count=10 " \
    "The ROS 2 image publisher did not finish the expected stream"
  assert_log_contains "$listener_log" "IMAGE_STREAM_OK count=10 " \
    "The MoonBit image listener did not receive the complete ROS 2 stream"
}

# Build every fixture before starting any probe so compilation time is not
# counted against discovery timeouts. Scenario processes invoke the built
# executables directly, so concurrent scenarios do not contend on the MoonBit
# build system while they run.
build_artifacts="$tmp_dir/build-artifacts.json"
"${moon_build_command[@]}" --output-json \
  cmd/ros2-mbt \
  examples/image_listener \
  examples/image_talker \
  examples/listener \
  examples/node_talker \
  examples/service_client \
  examples/service_server \
  examples/talker \
  examples/wstring_listener \
  examples/wstring_talker >"$build_artifacts"

fixture_paths=()
while IFS= read -r artifact_line; do
  [[ -n "$artifact_line" ]] || continue
  artifact_path=$(sed -n 's/.*"path":"\([^"]*\)".*/\1/p' <<<"$artifact_line")
  [[ -n "$artifact_path" ]] || continue
  artifact_directory=$(dirname "$artifact_path")
  artifact_relative="$(basename "$(dirname "$artifact_directory")")/$(basename "$artifact_directory")"
  fixture_paths+=("$artifact_relative=$artifact_path")
done <"$build_artifacts"

fixture_executable() {
  local fixture="$1"
  local entry
  for entry in "${fixture_paths[@]}"; do
    if [[ "$entry" == "$fixture="* ]]; then
      printf '%s\n' "${entry#*=}"
      return 0
    fi
  done
  echo "no build artifact was reported for $fixture" >&2
  return 1
}

topic_list_executable=$(fixture_executable cmd/ros2-mbt)
image_listener_executable=$(fixture_executable examples/image_listener)
image_talker_executable=$(fixture_executable examples/image_talker)
talker_executable=$(fixture_executable examples/talker)
listener_executable=$(fixture_executable examples/listener)
node_talker_executable=$(fixture_executable examples/node_talker)
service_client_executable=$(fixture_executable examples/service_client)
service_server_executable=$(fixture_executable examples/service_server)
wstring_listener_executable=$(fixture_executable examples/wstring_listener)
wstring_talker_executable=$(fixture_executable examples/wstring_talker)

start_scenario topic_list run_topic_list
start_scenario moonbit_talker run_moonbit_talker
start_scenario two_subscribers run_two_subscribers
start_scenario publisher_first run_publisher_first
start_scenario ros_publisher_to_listener run_ros_publisher_to_listener
start_scenario ros_publisher_to_late_listener run_ros_publisher_to_listener
start_scenario wstring_talker run_wstring_talker
start_scenario wstring_listener run_wstring_listener
start_scenario moonbit_service_server run_moonbit_service_server
start_scenario ros_service_server run_ros_service_server
start_scenario node_talker run_node_talker
start_scenario moonbit_image_talker run_moonbit_image_talker
start_scenario ros_image_publisher run_ros_image_publisher

run_queued_scenarios

if [[ "$failed" -ne 0 ]]; then
  echo "ROS 2 interoperability checks failed" >&2
  exit 1
fi

echo "ROS 2 String/WString/Image topic, graph, service, and node API interoperability passed."
