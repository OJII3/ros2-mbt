#!/usr/bin/env python3
"""A deterministic ROS 2 Fibonacci action server for MoonBit interop tests."""

import time

import rclpy
from rclpy.callback_groups import ReentrantCallbackGroup
from example_interfaces.action import Fibonacci
from rclpy.action import ActionServer, CancelResponse
from rclpy.executors import MultiThreadedExecutor
from rclpy.node import Node


class FibonacciActionServer(Node):
    def __init__(self) -> None:
        super().__init__("moonbit_fibonacci_action_server")
        self._action_server = ActionServer(
            self,
            Fibonacci,
            "/fibonacci",
            cancel_callback=self.cancel_callback,
            execute_callback=self.execute_callback,
            callback_group=ReentrantCallbackGroup(),
        )

    def cancel_callback(self, goal_handle):
        return CancelResponse.ACCEPT

    def execute_callback(self, goal_handle):
        order = goal_handle.request.order
        sequence = [0] if order > 0 else []
        if order > 1:
            sequence.append(1)
        while len(sequence) < order:
            time.sleep(0.2)
            if goal_handle.is_cancel_requested:
                goal_handle.canceled()
                result = Fibonacci.Result()
                result.sequence = sequence
                self.get_logger().info(
                    f"Canceled Fibonacci order {order}: {result.sequence}"
                )
                return result
            sequence.append(sequence[-1] + sequence[-2])
            feedback = Fibonacci.Feedback()
            feedback.sequence = sequence
            goal_handle.publish_feedback(feedback)

        goal_handle.succeed()
        result = Fibonacci.Result()
        result.sequence = sequence
        self.get_logger().info(f"Completed Fibonacci order {order}: {result.sequence}")
        return result


def main() -> None:
    rclpy.init()
    node = FibonacciActionServer()
    executor = MultiThreadedExecutor()
    executor.add_node(node)
    print("FIBONACCI_ACTION_SERVER_READY", flush=True)
    try:
        executor.spin()
    finally:
        executor.shutdown()
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


if __name__ == "__main__":
    main()
