inputs: let
  # OVERLAYS = with inputs; [
  #   nur.overlays.default
  #   deploy-rs.overlays.default
  #   # neovim.overlays.default
  #   niri.overlays.niri
  #   fenix.overlays.default
  # ];
  _o = obj: {attr ? "default"}: obj.overlays.${attr};
  OVERLAYS = with inputs; [
    (_o nur {})
    (_o deploy-rs {})
    (_o niri {attr = "niri";})
    (_o fenix {})
    (_o emacs-bleeding-edge {})
    (final: prev: {
      # The default x86_64-linux Bun binary currently segfaults on this build
      # host before printing --version. Use Bun's official baseline build so
      # Bun-based packages can build locally instead of relying on substitutes.
      bun =
        if prev.stdenv.hostPlatform.system == "x86_64-linux"
        then
          prev.bun.overrideAttrs (_old: {
            src = final.fetchurl {
              url = "https://github.com/oven-sh/bun/releases/download/bun-v1.3.11/bun-linux-x64-baseline.zip";
              hash = "sha256-q+NG9jQUVHzfazW3pkmkkMcouT0AYiYVaSORioTA5Zs=";
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
      # zjstatus zellij plugin
      zjstatus = inputs.zjstatus.packages.${prev.system}.default;
      inherit (inputs.zjstatus.packages.${prev.system}) zjframes;
    })
  ];
  # list of packages to use from stable
  # USE_FROM_STABLE = channels:
  #   with channels.stable; {
  #     inherit
  #       ncdu # just for testing
  #       ;
  #   };
in {
  _channels.overlays = OVERLAYS;
  # _channels.use_from_stable = USE_FROM_STABLE;
  channelsConfig.allowUnfree = true;
  sharedOverlays = OVERLAYS;
  channels = {
    stable.input = inputs.stable;
    unstable = {
      input = inputs.unstable;
      # overlaysBuilder = channels: [
      #   (_: _: USE_FROM_STABLE channels)
      # ];
    };
    unstable-small = {
      input = inputs.unstable-small;
    };
  };
}
