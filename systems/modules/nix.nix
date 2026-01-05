{
  lib,
  config,
  ...
}: let
  cfg = config.my_nix;
in {
  nix = {
    generateRegistryFromInputs = lib.mkDefault true;
    settings = {
      trusted-users = [cfg.username];
      warn-dirty = false;
      auto-optimise-store = true;
      experimental-features = ["nix-command" "flakes" "ca-derivations"];
      download-buffer-size = lib.mkDefault 524288000; # 500mb

      substituters = [
        "https://nix-community.cachix.org"
      ];

      extra-substituters = [
        "https://cache.nixos.org/"
        "https://cache.garnix.io"
        "https://hyprland.cachix.org"
      ];
      extra-trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      ];
    };

    # garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  environment.variables.LD_LIBRARY_PATH = lib.mkForce [
    "/run/current-system/sw/lib"
  ];
}
