#!/usr/bin/env python3
"""Assert MoonBit ROS graph metadata is visible to a ROS 2 participant."""

import os
import sys
import time

import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node


EXPECTED_CHATTER_WRITER_GID = bytes(
    [77, 66, 84, 82, 80, 83, 0, 0, 0, 0, 0, 42, 0, 0, 42, 3]
)


class RosGraphObserver(Node):
    def __init__(self) -> None:
        super().__init__("moonbit_ros_graph_observer")
        self.moon_talker_writer_gids: list[str] = []

    def observe(self) -> bool:
        publishers = self.get_publishers_info_by_topic("/chatter")
        self.moon_talker_writer_gids = [
            bytes(endpoint.endpoint_gid).hex()
            for endpoint in publishers
            if endpoint.node_namespace == "/demo"
            and endpoint.node_name == "moon_talker"
        ]
        return EXPECTED_CHATTER_WRITER_GID.hex() in self.moon_talker_writer_gids


def main() -> int:
    rclpy.init()
    node = RosGraphObserver()
    deadline = time.monotonic() + float(os.environ.get("ROS2_MBT_GRAPH_TIMEOUT", "40"))
    graph_publishers: list[str] = []
    discovered_nodes: list[tuple[str, str]] = []
    try:
        while rclpy.ok() and time.monotonic() < deadline:
            if node.observe():
                break
            rclpy.spin_once(node, timeout_sec=0.2)
        if rclpy.ok():
            discovered_nodes = node.get_node_names_and_namespaces()
            graph_publishers = [
                f"{endpoint.node_namespace}/{endpoint.node_name}:{endpoint.topic_type}:"
                f"{bytes(endpoint.endpoint_gid).hex()}"
                for endpoint in node.get_publishers_info_by_topic("/chatter")
            ]
    except ExternalShutdownException:
        pass
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()
    if EXPECTED_CHATTER_WRITER_GID.hex() not in node.moon_talker_writer_gids:
        print(
            "ROS 2 graph observer timed out: "
            f"discovered_chatter_publishers={graph_publishers}, "
            f"moon_talker_writer_gids={node.moon_talker_writer_gids}, "
            f"discovered_nodes={discovered_nodes}",
            file=sys.stderr,
        )
        return 1
    print("ROS_DISCOVERY_INFO_MATCHED /demo/moon_talker /chatter", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
