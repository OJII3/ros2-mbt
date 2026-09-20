#!/usr/bin/env python3
"""Assert MoonBit ROS graph metadata is visible to a ROS 2 participant."""

import os
import sys
import time

import rclpy
from rmw_dds_common.msg import ParticipantEntitiesInfo
from rclpy.node import Node
from rclpy.qos import (
    DurabilityPolicy,
    HistoryPolicy,
    QoSProfile,
    ReliabilityPolicy,
)


EXPECTED_CHATTER_WRITER_GID = bytes(
    [77, 66, 84, 82, 80, 83, 0, 0, 0, 0, 0, 42, 0, 0, 42, 3]
)


class RosGraphObserver(Node):
    def __init__(self) -> None:
        super().__init__("moonbit_ros_graph_observer")
        self.matched_graph = False
        self.graph_samples = 0
        self.moon_talker_writer_gids: list[str] = []
        graph_qos = QoSProfile(
            history=HistoryPolicy.KEEP_LAST,
            depth=1,
            reliability=ReliabilityPolicy.RELIABLE,
            durability=DurabilityPolicy.TRANSIENT_LOCAL,
        )
        self._subscription = self.create_subscription(
            ParticipantEntitiesInfo,
            "ros_discovery_info",
            self.observe,
            graph_qos,
        )

    def observe(self, message: ParticipantEntitiesInfo) -> None:
        self.graph_samples += 1
        for node_info in message.node_entities_info_seq:
            if (
                node_info.node_namespace != "/demo"
                or node_info.node_name != "moon_talker"
            ):
                continue
            writer_gids = [
                bytes(gid.data).hex() for gid in node_info.writer_gid_seq
            ]
            self.moon_talker_writer_gids = writer_gids
            if EXPECTED_CHATTER_WRITER_GID.hex() in writer_gids:
                self.matched_graph = True
                print(
                    "ROS_DISCOVERY_INFO_MATCHED /demo/moon_talker /chatter",
                    flush=True,
                )
                return


def main() -> int:
    rclpy.init()
    node = RosGraphObserver()
    deadline = time.monotonic() + float(os.environ.get("ROS2_MBT_GRAPH_TIMEOUT", "35"))
    graph_publishers: list[str] = []
    graph_subscriptions: list[str] = []
    try:
        while rclpy.ok() and not node.matched_graph and time.monotonic() < deadline:
            rclpy.spin_once(node, timeout_sec=0.2)
        graph_publishers = [
            f"{endpoint.node_namespace}/{endpoint.node_name}:{endpoint.topic_type}"
            for endpoint in node.get_publishers_info_by_topic("ros_discovery_info")
        ]
        graph_subscriptions = [
            f"{endpoint.node_namespace}/{endpoint.node_name}:{endpoint.topic_type}"
            for endpoint in node.get_subscriptions_info_by_topic("ros_discovery_info")
        ]
    finally:
        node.destroy_node()
        rclpy.shutdown()
    if not node.matched_graph:
        print(
            "ROS 2 graph observer timed out: "
            f"graph_samples={node.graph_samples}, "
            f"discovered_publishers={graph_publishers}, "
            f"discovered_subscriptions={graph_subscriptions}, "
            f"moon_talker_writer_gids={node.moon_talker_writer_gids}",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
