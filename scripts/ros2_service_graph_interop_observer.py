#!/usr/bin/env python3
"""Wait for the MoonBit AddTwoInts server in the ROS 2 graph."""

import os
import sys
import time

import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node


EXPECTED_NODE = ("moon_add_two_ints_server", "/demo")


def main() -> int:
    rclpy.init()
    node = Node("moonbit_ros_service_graph_observer")
    deadline = time.monotonic() + float(
        os.environ.get("ROS2_MBT_GRAPH_TIMEOUT", "60")
    )
    discovered_nodes: list[tuple[str, str]] = []
    print("ROS_GRAPH_OBSERVER_READY", flush=True)
    try:
        while rclpy.ok() and time.monotonic() < deadline:
            discovered_nodes = node.get_node_names_and_namespaces()
            if EXPECTED_NODE in discovered_nodes:
                break
            rclpy.spin_once(node, timeout_sec=0.2)
    except ExternalShutdownException:
        pass
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()

    if EXPECTED_NODE not in discovered_nodes:
        print(
            "ROS 2 graph observer timed out: "
            f"expected_node={EXPECTED_NODE}, discovered_nodes={discovered_nodes}",
            file=sys.stderr,
        )
        return 1
    print("ROS_DISCOVERY_INFO_MATCHED /demo/moon_add_two_ints_server", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
