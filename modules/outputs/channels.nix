{inputs, ...}: let
  _o = obj: {attr ? "default"}: obj.overlays.${attr};
  overlays = with inputs; [
    (_o nur {})
    (_o deploy-rs {})
    (_o niri {attr = "niri";})
    (_o fenix {})
    (_o emacs-bleeding-edge {})
    (final: prev: {
      bun =
        if prev.stdenv.hostPlatform.system == "x86_64-linux"
        then
          prev.bun.overrideAttrs (_old: {
            src = final.fetchurl {
              url = "https://github.com/oven-sh/bun/releases/download/bun-v1.3.13/bun-linux-x64-baseline.zip";
              hash = "sha256-nYokKSpwaAkCBdqsCloiP19pc29Sh+N7+I07QDHtx1A=";
            };
            sourceRoot = "bun-linux-x64-baseline";
          })
        else prev.bun;
    })
    (_o llm-agents {})
    (final: prev: {
      llm-agents =
        prev.llm-agents
        // {
          omp = prev.llm-agents.omp.overrideAttrs (old: {
            preBunPatchPhase =
              (old.preBunPatchPhase or "")
              + ''
                export PATH="${final.bun}/bin:$PATH"
              '';
            buildPhase =
              builtins.replaceStrings
              ["--target=\"bun-linux-x64-modern\""]
              ["--target=\"bun-linux-x64-baseline\""]
              old.buildPhase;
          });
        };
    })
    (_: prev: {
      zjstatus = inputs.zjstatus.packages.${prev.system}.default;
      inherit (inputs.zjstatus.packages.${prev.system}) zjframes;
    })
  ];
  mk_pkgs = system: let
    import_channel = input:
      import input {
        inherit system overlays;
        config.allowUnfree = true;
      };
  in rec {
    stable = import_channel inputs.stable;
    unstable = import_channel inputs.unstable;
    unstable-small = import_channel inputs.unstable-small;
    default = unstable;
  };
in {
  flake = {
    _channels.overlays = overlays;
    channelsConfig.allowUnfree = true;
    sharedOverlays = overlays;
    pkgs.x86_64-linux = mk_pkgs "x86_64-linux";
    channels = {
      stable.input = inputs.stable;
      unstable.input = inputs.unstable;
      unstable-small.input = inputs.unstable-small;
    };
  };
}
