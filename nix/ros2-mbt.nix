{
  lib,
  moonPlatform,
  moonModJson,
  moonRegistryIndex,
}:

moonPlatform.buildMoonPackage {
  name = "ros2-mbt";
  version = "0.1.0";

  src = lib.cleanSource ../.;

  inherit moonModJson moonRegistryIndex;
  moonFlags = [ "cmd/ros2-mbt" ];
  doCheck = false;

  meta = {
    description = "A small DDS/RTPS compatibility layer for MoonBit and ROS 2";
    homepage = "https://github.com/OJII3/ros2-mbt";
    license = lib.licenses.mit;
    mainProgram = "ros2-mbt";
    platforms = lib.platforms.unix;
  };
}
