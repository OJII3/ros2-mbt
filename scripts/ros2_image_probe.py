#!/usr/bin/env python3
"""Publish or subscribe to a deterministic sensor_msgs/Image stream."""

from __future__ import annotations

import argparse
import array
import hashlib
import sys
import time

import rclpy
from rclpy.node import Node
from rclpy.qos import DurabilityPolicy, HistoryPolicy, QoSProfile, ReliabilityPolicy
from sensor_msgs.msg import Image


def image_pattern(width: int, height: int) -> bytes:
    size = width * height * 3
    return (bytes(range(251)) * (size // 251 + 1))[:size]


def payload_digest(data: object) -> str:
    return hashlib.blake2b(memoryview(data), digest_size=8).hexdigest()


class ImageStreamProbe(Node):
    def __init__(self, args: argparse.Namespace) -> None:
        super().__init__(f"ros2_image_probe_{args.mode}")
        self.args = args
        self.seen = [False] * args.count
        self.received = 0
        self.invalid = False
        self.first_ms: float | None = None
        self.expected_digest = payload_digest(
            image_pattern(args.width, args.height)
        )
        qos = QoSProfile(
            history=HistoryPolicy.KEEP_LAST,
            depth=max(10, args.count),
            reliability=ReliabilityPolicy.RELIABLE,
            durability=DurabilityPolicy.VOLATILE,
        )
        if args.mode == "subscribe":
            self.create_subscription(Image, args.topic, self.on_image, qos)
            print(
                f"IMAGE_PROBE_READY topic={args.topic} count={args.count} "
                f"width={args.width} height={args.height}",
                flush=True,
            )
        else:
            self.publisher = self.create_publisher(Image, args.topic, qos)
            print(f"IMAGE_PUBLISHER_READY topic={args.topic}", flush=True)

    def on_image(self, message: Image) -> None:
        index = message.header.stamp.sec
        data = message.data
        valid = (
            0 <= index < self.args.count
            and not self.seen[index]
            and message.width == self.args.width
            and message.height == self.args.height
            and message.encoding == "rgb8"
            and message.is_bigendian == 0
            and message.step == self.args.width * 3
            and len(data) == self.args.width * self.args.height * 3
            and payload_digest(data) == self.expected_digest
        )
        if not valid:
            print(
                f"IMAGE_INVALID index={index} bytes={len(data)} "
                f"digest={payload_digest(data)}",
                flush=True,
            )
            self.invalid = True
            return
        if self.first_ms is None:
            self.first_ms = time.monotonic()
        self.seen[index] = True
        self.received += 1
        print(
            f"IMAGE_RECEIVED index={index} bytes={len(data)} "
            f"digest={self.expected_digest}",
            flush=True,
        )

    def wait_for_subscriber(self) -> bool:
        deadline = time.monotonic() + self.args.timeout
        while rclpy.ok() and time.monotonic() < deadline:
            rclpy.spin_once(self, timeout_sec=0.1)
            if self.publisher.get_subscription_count() > 0:
                print("IMAGE_PUBLISHER_MATCHED", flush=True)
                return True
        print("IMAGE_PUBLISHER_TIMEOUT", flush=True)
        return False

    def publish_stream(self) -> int:
        if not self.wait_for_subscriber():
            return 1
        payload = array.array("B", image_pattern(self.args.width, self.args.height))
        next_ms = time.monotonic()
        for index in range(self.args.count):
            message = Image()
            message.header.stamp.sec = index
            message.header.stamp.nanosec = 0
            message.header.frame_id = f"image-{index}"
            message.height = self.args.height
            message.width = self.args.width
            message.encoding = "rgb8"
            message.is_bigendian = 0
            message.step = self.args.width * 3
            message.data = payload
            self.publisher.publish(message)
            print(f"IMAGE_PUBLISHED index={index}", flush=True)
            next_ms += self.args.period_ms / 1000.0
            delay = next_ms - time.monotonic()
            if delay > 0:
                time.sleep(delay)
        linger_deadline = time.monotonic() + self.args.linger_ms / 1000.0
        while rclpy.ok() and time.monotonic() < linger_deadline:
            rclpy.spin_once(self, timeout_sec=0.05)
        print(
            f"IMAGE_PUBLISHER_DONE count={self.args.count} "
            f"bytes={self.args.width * self.args.height * 3 * self.args.count}",
            flush=True,
        )
        return 0

    def receive_stream(self) -> int:
        deadline = time.monotonic() + self.args.timeout
        while (
            rclpy.ok()
            and time.monotonic() < deadline
            and self.received < self.args.count
            and not self.invalid
        ):
            rclpy.spin_once(self, timeout_sec=0.1)
        if self.invalid:
            print("IMAGE_STREAM_INVALID", flush=True)
            return 1
        if self.received < self.args.count:
            missing = [index for index, seen in enumerate(self.seen) if not seen]
            print(
                f"IMAGE_TIMEOUT received={self.received} missing={missing}",
                flush=True,
            )
            return 1
        elapsed_ms = int((time.monotonic() - self.first_ms) * 1000.0)
        if elapsed_ms > self.args.max_stream_ms:
            print(
                f"IMAGE_STREAM_SLOW count={self.received} elapsed_ms={elapsed_ms}",
                flush=True,
            )
            return 1
        print(
            f"IMAGE_STREAM_OK count={self.received} "
            f"bytes={self.args.width * self.args.height * 3 * self.args.count} "
            f"elapsed_ms={elapsed_ms}",
            flush=True,
        )
        return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("publish", "subscribe"), required=True)
    parser.add_argument("--topic", default="/image")
    parser.add_argument("--count", type=int, default=10)
    parser.add_argument("--width", type=int, default=640)
    parser.add_argument("--height", type=int, default=480)
    parser.add_argument("--period-ms", type=float, default=50.0)
    parser.add_argument("--linger-ms", type=float, default=1000.0)
    parser.add_argument("--timeout", type=float, default=30.0)
    parser.add_argument("--max-stream-ms", type=int, default=10000)
    args = parser.parse_args()
    if args.count <= 0 or args.width <= 0 or args.height <= 0:
        parser.error("--count, --width, and --height must be positive")
    if args.period_ms < 0 or args.linger_ms < 0 or args.timeout <= 0:
        parser.error("--period-ms and --linger-ms must not be negative")
    return args


def main() -> int:
    args = parse_args()
    rclpy.init(args=[])
    node = ImageStreamProbe(args)
    try:
        if args.mode == "publish":
            return node.publish_stream()
        return node.receive_stream()
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


if __name__ == "__main__":
    sys.exit(main())
