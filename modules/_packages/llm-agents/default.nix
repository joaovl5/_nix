{
  pkgs,
  inputs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
  upstream = inputs.llm-agents.packages.${system};
  baseline_bun =
    if system == "x86_64-linux"
    then
      pkgs.bun.overrideAttrs (_old: {
        src = pkgs.fetchurl {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v1.3.13/bun-linux-x64-baseline.zip";
          hash = "sha256-nYokKSpwaAkCBdqsCloiP19pc29Sh+N7+I07QDHtx1A=";
        };
        sourceRoot = "bun-linux-x64-baseline";
      })
    else pkgs.bun;

  omp = upstream.omp.overrideAttrs (old: {
    preBunPatchPhase =
      (old.preBunPatchPhase or "")
      + ''
        export PATH="${baseline_bun}/bin:$PATH"
      '';
    buildPhase =
      builtins.replaceStrings
      ["--target=\"bun-linux-x64-modern\""]
      ["--target=\"bun-linux-x64-baseline\""]
      old.buildPhase;
  });
in
  upstream
  // {
    bun = baseline_bun;
    inherit omp;
  }
