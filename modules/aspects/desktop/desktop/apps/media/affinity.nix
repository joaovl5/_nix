_: {
  den.aspects.desktop.nixos = {
    pkgs,
    inputs,
    ...
  }: {
    nixpkgs.overlays = [inputs.affinity-nix.overlays.default];
    environment.systemPackages = [pkgs.affinity-v3];

    nix.settings.substituters = ["https://cache.forall.systems"];
    nix.settings.trusted-public-keys = ["cache.forall.systems:5PmD7QO4MSF8YgyRZtkSGXRDo96H3bybIf2SsQh8ScI="];
  };
}
