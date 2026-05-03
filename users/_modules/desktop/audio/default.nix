{
  hm = {pkgs, ...}: {
    services.easyeffects = {
      enable = true;
      extraPresets =
        (import ./easyeffects_presets/output.nix)
        // (import ./easyeffects_presets/input.nix);
    };

    home.packages = with pkgs; [
      qpwgraph
    ];
  };
}
