{
  autoPatchelfHook,
  fetchurl,
  lib,
  openssl,
  stdenv,
  zlib,
  ...
}:
stdenv.mkDerivation {
  pname = "beads-web";
  version = "0.11.0";

  src = fetchurl {
    url = "https://github.com/weselow/beads-web/releases/download/v0.11.0/beads-web-linux-x64";
    hash = "sha256-6v6xkAeOxJEqLPZwKht5kOfGWC1oqhY7oLdu6Q/LXgs=";
  };

  dontUnpack = true;

  nativeBuildInputs = [autoPatchelfHook];

  buildInputs = [
    openssl
    stdenv.cc.cc.lib
    zlib
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/beads-web"

    runHook postInstall
  '';

  meta = {
    description = "Web UI for Beads with embedded frontend";
    homepage = "https://github.com/weselow/beads-web";
    license = lib.licenses.mit;
    mainProgram = "beads-web";
    platforms = ["x86_64-linux"];
    sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
  };
}
