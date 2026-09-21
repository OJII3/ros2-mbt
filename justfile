# Show available tasks.
default:
    @just --list

# Format source files.
fmt:
    moon fmt

# Check formatting, types, and native tests.
verify: fmt-check check test

fmt-check:
    moon fmt --check

check:
    moon check

test:
    moon test --target native

# Run ROS 2 Jazzy interoperability checks.
interop-cli:
    nix develop .#ros2 --command bash scripts/ros2_cli_interop.sh

interop-action:
    nix develop .#ros2 --command bash scripts/ros2_action_interop.sh

interop-parameter:
    nix develop .#ros2 --command bash scripts/ros2_parameter_interop.sh

# Run all checks and interoperability tests in Podman.
interop-podman:
    bash scripts/ros2_podman_interop.sh
