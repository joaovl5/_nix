{
  buildGoModule,
  inputs,
  lib,
  ...
}: let
  src = inputs.mardi-gras-src.outPath;
  tag = inputs.mardi-gras-src.version or "unstable";
  version = lib.removePrefix "v" tag;
in
  buildGoModule {
    pname = "mardi-gras";
    inherit src version;

    subPackages = ["cmd/mg"];
    vendorHash = "sha256-FuXR6Cq+BLJ7h5UqFEDJ/BVlWIUpye7GOpiqbhjv6aM=";

    ldflags = [
      "-s"
      "-w"
      "-X main.version=${tag}"
    ];
    postInstall = ''
      install -Dm444 mg.1 "$out/share/man/man1/mg.1"
    '';

    meta = {
      description = "Terminal UI for Beads issues";
      homepage = "https://github.com/quietpublish/mardi-gras";
      license = lib.licenses.mit;
      mainProgram = "mg";
      platforms = lib.platforms.unix;
    };
  }
