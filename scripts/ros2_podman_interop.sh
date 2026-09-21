#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd "$script_dir/.." && pwd)
image=${ROS2_MBT_PODMAN_IMAGE:-localhost/ros2-mbt-jazzy:local}
ros_domain_id=${ROS_DOMAIN_ID:-42}
discovery_range=${ROS_AUTOMATIC_DISCOVERY_RANGE:-SUBNET}

if ! command -v podman >/dev/null 2>&1; then
  echo "Podman not found; install Podman and initialize its machine on macOS" >&2
  exit 127
fi

podman build \
  --file "$repo_dir/podman/ros2-jazzy/Containerfile" \
  --tag "$image" \
  "$repo_dir/podman/ros2-jazzy"

podman run --rm \
  --volume "$repo_dir:/source:ro" \
  --env ROS_DOMAIN_ID="$ros_domain_id" \
  --env ROS_AUTOMATIC_DISCOVERY_RANGE="$discovery_range" \
  --entrypoint /bin/bash \
  "$image" -lc '
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
    cd /tmp/ros2-mbt

    runner_ip=$(ip -4 route get 239.255.0.1 | awk '\''
      {for (i = 1; i <= NF; i++) if ($i == "src") {print $(i + 1); exit}}
    '\'')
    if [[ -z "$runner_ip" ]]; then
      echo "Could not determine the container IPv4 address for multicast discovery" >&2
      exit 1
    fi
    export ROS2_MBT_IP="$runner_ip"
    export ROS2_MBT_MULTICAST_IP="$runner_ip"

    moon update
    moon fmt --check
    moon check
    moon test --target native
    bash /source/scripts/ros2_cli_interop.sh
    bash /source/scripts/ros2_action_interop.sh
    bash /source/scripts/ros2_parameter_interop.sh
  '
