#!/usr/bin/env python3
"""Small ROS 2 node exposing the standard parameter services for interop tests."""

import rclpy
from rclpy.node import Node


def main():
    rclpy.init()
    node = Node("moon_parameter_server", namespace="/demo")
    node.declare_parameter("answer", 42)
    node.get_logger().info("GET_PARAMETERS_SERVER_READY")
    try:
        rclpy.spin(node)
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
