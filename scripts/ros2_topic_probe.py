#!/usr/bin/env python3
"""Wait for a ROS 2 subscription match and receive matching samples."""

from __future__ import annotations

import argparse
import os
import sys
import time

import rclpy
from rclpy.event_handler import SubscriptionEventCallbacks
from rclpy.node import Node
from rclpy.qos import DurabilityPolicy, HistoryPolicy, QoSProfile, ReliabilityPolicy


class TopicProbe(Node):
    def __init__(self, topic: str, message_type: type, reliability: str) -> None:
        super().__init__(f"ros2_topic_probe_{os.getpid()}")
        self.topic = topic
        self.matched = False
        self.received = 0
        self.message_type = message_type
        self.reliability = reliability

    def has_publisher(self, expected_node: str) -> bool:
        for endpoint in self.get_publishers_info_by_topic(self.topic):
            full_name = f"{endpoint.node_namespace.rstrip('/')}/{endpoint.node_name}"
            if full_name == expected_node:
                return True
        return False

    def create_probe_subscription(self, expected_prefix: str) -> None:
        reliability = (
            ReliabilityPolicy.BEST_EFFORT
            if self.reliability == "best_effort"
            else ReliabilityPolicy.RELIABLE
        )
        qos = QoSProfile(
            history=HistoryPolicy.KEEP_LAST,
            depth=10,
            reliability=reliability,
            durability=DurabilityPolicy.VOLATILE,
        )

        def on_message(message: object) -> None:
            data = message.data
            if expected_prefix and not data.startswith(expected_prefix):
                return
            self.received += 1
            print(f"PROBE_RECEIVED {data}", flush=True)

        def on_matched(event: object) -> None:
            if event.current_count > 0:
                self.matched = True
                print(f"PROBE_MATCHED current_count={event.current_count}", flush=True)

        self.create_subscription(
            self.message_type,
            self.topic,
            on_message,
            qos,
            event_callbacks=SubscriptionEventCallbacks(matched=on_matched),
        )
        print(f"PROBE_READY {self.topic} {self.reliability}", flush=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--topic", required=True)
    parser.add_argument("--type", choices=("string", "wstring"), required=True)
    parser.add_argument(
        "--reliability",
        choices=("reliable", "best_effort"),
        default="reliable",
    )
    parser.add_argument("--expected-prefix", default="")
    parser.add_argument("--publisher", help="Wait for this fully qualified ROS node before subscribing")
    parser.add_argument("--timeout", type=float, default=30.0)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.type == "string":
        from std_msgs.msg import String as MessageType
    else:
        from example_interfaces.msg import WString as MessageType

    rclpy.init(args=[])
    node = TopicProbe(args.topic, MessageType, args.reliability)
    deadline = time.monotonic() + args.timeout
    try:
        if args.publisher:
            while time.monotonic() < deadline and not node.has_publisher(args.publisher):
                rclpy.spin_once(node, timeout_sec=0.1)
            if not node.has_publisher(args.publisher):
                print(f"PROBE_TIMEOUT publisher={args.publisher}", file=sys.stderr)
                return 1
            print(f"PROBE_PUBLISHER_FOUND {args.publisher}", flush=True)

        node.create_probe_subscription(args.expected_prefix)
        while (
            rclpy.ok()
            and time.monotonic() < deadline
            and (not node.matched or node.received == 0)
        ):
            rclpy.spin_once(node, timeout_sec=0.1)

        if not node.matched or node.received == 0:
            print(
                f"PROBE_TIMEOUT matched={node.matched} received={node.received}",
                file=sys.stderr,
            )
            return 1
        return 0
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


if __name__ == "__main__":
    sys.exit(main())
