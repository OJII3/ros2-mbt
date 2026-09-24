#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd "$script_dir/.." && pwd)
image=${ROS2_MBT_PODMAN_IMAGE:-localhost/ros2-mbt-jazzy:local}
container_name=ros2-mbt-ci
ros_domain_id=${ROS_DOMAIN_ID:-42}
discovery_range=${ROS_AUTOMATIC_DISCOVERY_RANGE:-SUBNET}
stage=${1:-all}

if ! command -v podman >/dev/null 2>&1; then
  echo "Podman not found; install Podman and initialize its machine on macOS" >&2
  exit 127
fi

stop_container() {
  if podman container exists "$container_name"; then
    podman rm --force "$container_name"
  fi
}

start_container() {
  if [[ "${ROS2_MBT_PODMAN_BUILD:-1}" != "0" ]]; then
    podman build \
      --file "$repo_dir/podman/ros2-jazzy/Containerfile" \
      --tag "$image" \
      "$repo_dir/podman/ros2-jazzy"
  fi

  stop_container
  podman run --detach \
    --name "$container_name" \
    --volume "$repo_dir:/source:ro" \
    --env ROS_DOMAIN_ID="$ros_domain_id" \
    --env ROS_AUTOMATIC_DISCOVERY_RANGE="$discovery_range" \
    --entrypoint /bin/bash \
    "$image" -lc 'while :; do sleep 3600; done'

  podman exec "$container_name" /bin/bash -lc '
    set -euo pipefail
    set +u
    source /opt/ros/jazzy/setup.bash
    set -u
    mkdir -p /tmp/ros2-mbt
    tar \
      --exclude=.git \
      --exclude=.codex \
      --exclude=.direnv \
      --exclude=.moon \
      --exclude=.mooncakes \
      --exclude=target \
      -C /source -cf - . | tar -C /tmp/ros2-mbt -xf -

    runner_ip=$(ip -4 route get 239.255.0.1 | awk '\''
      {for (i = 1; i <= NF; i++) if ($i == "src") {print $(i + 1); exit}}
    '\'')
    if [[ -z "$runner_ip" ]]; then
      echo "Could not determine the container IPv4 address for multicast discovery" >&2
      exit 1
    fi
    printf "%s" "$runner_ip" > /tmp/ros2-mbt-runner-ip
  '
}

run_in_container() {
  local command=$1
  podman exec --workdir /tmp/ros2-mbt "$container_name" /bin/bash -lc "
    set -euo pipefail
    set +u
    source /opt/ros/jazzy/setup.bash
    set -u
    cd /tmp/ros2-mbt
    runner_ip=\$(cat /tmp/ros2-mbt-runner-ip)
    export ROS2_MBT_IP=\"\$runner_ip\"
    export ROS2_MBT_MULTICAST_IP=\"\$runner_ip\"
    $command
  "
}

run_all() {
  trap stop_container EXIT
  start_container
  run_in_container 'moon update'
  run_in_container 'moon fmt --check'
  run_in_container 'moon check'
  run_in_container 'moon test --target native'
  run_in_container 'bash /source/scripts/ros2_cli_interop.sh'
  run_in_container 'bash /source/scripts/ros2_action_interop.sh'
  run_in_container 'bash /source/scripts/ros2_parameter_interop.sh'
}

case "$stage" in
  all)
    run_all
    ;;
  start)
    start_container
    ;;
  update)
    run_in_container 'moon update'
    ;;
  fmt)
    run_in_container 'moon fmt --check'
    ;;
  check)
    run_in_container 'moon check'
    ;;
  test)
    run_in_container 'moon test --target native'
    ;;
  cli)
    run_in_container 'bash /source/scripts/ros2_cli_interop.sh'
    ;;
  action)
    run_in_container 'bash /source/scripts/ros2_action_interop.sh'
    ;;
  parameter)
    run_in_container 'bash /source/scripts/ros2_parameter_interop.sh'
    ;;
  stop)
    stop_container
    ;;
  *)
    echo "Usage: $0 [all|start|update|fmt|check|test|cli|action|parameter|stop]" >&2
    exit 2
    ;;
esac
