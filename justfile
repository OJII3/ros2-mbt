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

# Native debug linking of `Array[@socket.Addr]` hits a MoonBit compiler ICE,
# so native tests run in release mode until the compiler supports it.
# https://github.com/moonbitlang/moonbit-docs/issues/1322
test:
    moon test --target native --release

# Run ROS 2 Jazzy interoperability checks.
interop-cli:
    nix develop .#ros2 --command bash scripts/ros2_cli_interop.sh

interop-action:
    nix develop .#ros2 --command bash scripts/ros2_action_interop.sh

interop-parameter:
    nix develop .#ros2 --command bash scripts/ros2_parameter_interop.sh

# Run ROS 2 interoperability tests in Podman.
interop-podman stage="all":
    bash scripts/ros2_podman_interop.sh "{{stage}}"
