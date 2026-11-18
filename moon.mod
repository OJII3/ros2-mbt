name = "OJII3/ros2-mbt"

version = "0.13.0"

readme = "README.md"

repository = "https://github.com/OJII3/ros2-mbt"

license = "MIT"

keywords = [ "dds", "rtps", "ros2" ]

preferred_target = "native"

description = "A small DDS/RTPS compatibility layer for MoonBit and ROS 2"

// Treat every compiler warning, including opt-in lints, as an error.

options(
  warnings: "+all@all",
)
