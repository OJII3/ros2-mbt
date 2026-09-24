{
  lib,
  moon2nix,
  moonRegistryIndex,
}:

moon2nix.buildMoonPackage {
  name = "ros2-mbt";
  version = "0.4.0";

  src = lib.cleanSource ../.;

  moonMod = {
    name = "OJII3/ros2-mbt";
    version = "0.4.0";
    preferred-target = "native";
    deps."moonbitlang/async" = "0.22.0";
  };
  inherit moonRegistryIndex;
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
