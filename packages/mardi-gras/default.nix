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
    vendorHash = "sha256-CbftluOGy00UtbStnH544kLAI63lC5rL3BZUp+Gf5Bc=";

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
