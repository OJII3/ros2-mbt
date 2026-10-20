#!/usr/bin/env python3
"""Check the node API's topic samples and ROS graph identity together."""

import subprocess
import sys
import time

import rclpy
from rclpy.node import Node
from rclpy.qos import DurabilityPolicy, QoSProfile, ReliabilityPolicy
from std_msgs.msg import String


def main() -> int:
    command = sys.argv[1:]
    if not command:
        raise SystemExit("usage: ros2_node_interop_probe.py <moon command> [args...]")
    rclpy.init(args=[])
    observer = Node("ros2_node_api_probe")
    received = []
    observer.create_subscription(
        String,
        "/chatter",
        lambda message: received.append(message.data),
        QoSProfile(
            depth=10,
            reliability=ReliabilityPolicy.RELIABLE,
            durability=DurabilityPolicy.VOLATILE,
        ),
    )
    process = subprocess.Popen(command)
    graph_matched = False
    publishers_seen = set()
    try:
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            rclpy.spin_once(observer, timeout_sec=0.1)
            publishers = observer.get_publishers_info_by_topic("/chatter")
            publishers_seen.update(
                (endpoint.node_namespace, endpoint.node_name, endpoint.topic_type)
                for endpoint in publishers
            )
            graph_matched = graph_matched or any(
                endpoint.node_namespace == "/demo"
                and endpoint.node_name == "moon_node_talker"
                and endpoint.topic_type == "std_msgs/msg/String"
                for endpoint in publishers
            )
            if process.poll() is not None:
                break
        if process.poll() is None:
            print("Node example did not shut down after five samples", file=sys.stderr)
            return 1
        if process.returncode != 0:
            return process.returncode
        if "hello from RosNode" not in received or not graph_matched:
            print(
                f"Node interoperability failed: graph={graph_matched}, "
                f"publishers={sorted(publishers_seen)}, samples={received}",
                file=sys.stderr,
            )
            return 1
        print("ROS_NODE_API_MATCHED /demo/moon_node_talker /chatter", flush=True)
        return 0
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        observer.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


if __name__ == "__main__":
    sys.exit(main())
