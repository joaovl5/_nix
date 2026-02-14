{
  hm = _: {
    services.easyeffects = {
      enable = true;
      extraPresets =
        (import ./easyeffects_presets/output.nix)
        // (import ./easyeffects_presets/input.nix);
    };
  };
}
