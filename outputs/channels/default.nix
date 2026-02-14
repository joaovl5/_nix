{self, ...} @ inputs: let
  _o = obj: obj.overlays.default;
  OVERLAYS = with inputs; [
    (_o self)
    (_o nur)
    (_o deploy-rs)
    # (_o neovim)
    (_o niri)
    (_o fenix)
  ];

  # list of packages to use from stable
  USE_FROM_STABLE = channels:
    with channels.stable; {
      inherit
        ncdu # just for testing
        ;
    };
in {
  channelsConfig.allowUnfree = true;
  sharedOverlays = OVERLAYS;
  channels = {
    stable.input = inputs.stable;
    unstable = {
      input = inputs.unstable;
      overlaysBuilder = channels: [
        (USE_FROM_STABLE channels)
      ];
    };
  };
  overlays.default = import ../../overlays;
}
