#!/usr/bin/env python3
"""A deterministic ROS 2 Fibonacci action server for MoonBit interop tests."""

import rclpy
from example_interfaces.action import Fibonacci
from rclpy.action import ActionServer
from rclpy.node import Node


class FibonacciActionServer(Node):
    def __init__(self) -> None:
        super().__init__("moonbit_fibonacci_action_server")
        self._action_server = ActionServer(
            self,
            Fibonacci,
            "/fibonacci",
            execute_callback=self.execute_callback,
        )

    def execute_callback(self, goal_handle):
        order = goal_handle.request.order
        sequence = [0, 1] if order > 1 else [0]
        while len(sequence) < order:
            sequence.append(sequence[-1] + sequence[-2])

        goal_handle.succeed()
        result = Fibonacci.Result()
        result.sequence = sequence[:order]
        self.get_logger().info(f"Completed Fibonacci order {order}: {result.sequence}")
        return result


def main() -> None:
    rclpy.init()
    node = FibonacciActionServer()
    print("FIBONACCI_ACTION_SERVER_READY", flush=True)
    try:
        rclpy.spin(node)
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
