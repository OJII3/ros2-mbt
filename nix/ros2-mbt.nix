{
  lib,
  stdenv,
  moonbit,
  asyncSrc,
}:

stdenv.mkDerivation {
  pname = "ros2-mbt";
  version = "0.1.0";

  src = lib.cleanSource ../.;

  nativeBuildInputs = [ moonbit ];

  postPatch = ''
    mkdir -p .mooncakes/moonbitlang/async
    cp -R ${asyncSrc}/. .mooncakes/moonbitlang/async/
    chmod -R u+w .mooncakes/moonbitlang/async
  '';

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    printf '%s\n' \
      'members = [' \
      '  "." ,' \
      '  ".mooncakes/moonbitlang/async" ,' \
      ']' > moon.work
    moon build --target native --release --frozen cmd/ros2-mbt
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 \
      _build/native/release/build/ojii3/ros2-mbt/cmd/ros2-mbt/ros2-mbt.exe \
      $out/bin/ros2-mbt
    runHook postInstall
  '';

  meta = {
    description = "A small DDS/RTPS compatibility layer for MoonBit and ROS 2";
    homepage = "https://github.com/OJII3/ros2-mbt";
    license = lib.licenses.mit;
    mainProgram = "ros2-mbt";
    platforms = lib.platforms.unix;
  };
}
