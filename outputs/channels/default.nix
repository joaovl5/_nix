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
    (_o llm-agents {})
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
