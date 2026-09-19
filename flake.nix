{
  description = "Basic DDS for moonbit and ROS 2";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
            overlays = [
              inputs.moonbit-overlay.overlays.default
            ];
          };
        in
        {
          devShells.default = pkgs.mkShell {
            packages = [
              pkgs.moonbit-bin.moonbit.latest
            ];
          };
        };

      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
    };
}
