{
  description = "Basic DDS for moonbit and ROS 2";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nix-ros-overlay.url = "github:lopsided98/nix-ros-overlay/master";
    nixpkgs.follows = "nix-ros-overlay/nixpkgs";
    moonbit-overlay.url = "github:moonbit-community/moonbit-overlay";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {

      perSystem =
        { system, ... }:
        let
          pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [ inputs.moonbit-overlay.overlays.default ];
          };
          rosPkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [
              inputs.moonbit-overlay.overlays.default
              inputs.nix-ros-overlay.overlays.default
            ];
          };
          moonbit = pkgs.moonbit-bin.moonbit.latest;
        in
        {
          devShells = {
            default = pkgs.mkShell {
              packages = [ moonbit pkgs.just ];
            };
            ros2 = rosPkgs.mkShell {
              packages = [
                moonbit
                pkgs.just
                rosPkgs.coreutils
                (rosPkgs.rosPackages.jazzy.buildEnv {
                  underlay = true;
                  paths = with rosPkgs.rosPackages.jazzy; [
                    ros-core
                    demo-nodes-cpp
                    example-interfaces
                    action-tutorials-interfaces
                  ];
                })
              ];
            };
          };
        };

      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
    };
}
