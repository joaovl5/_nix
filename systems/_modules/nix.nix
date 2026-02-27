{
  lib,
  config,
  ...
}: let
  cfg = config.my.nix;
in {
  nix = {
    generateRegistryFromInputs = lib.mkDefault true;
    daemonCPUSchedPolicy = lib.mkDefault (
      if cfg.is_server
      then "batch"
      else "idle"
    );

    settings = {
      trusted-users = [cfg.username];
      warn-dirty = false;
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
        "pipe-operator" # if not using lix, is `pipe-operators`
      ];

      substituters = [
        "https://nix-community.cachix.org"
        "https://cache.nixos.org/"
        "https://cache.garnix.io"
        "https://hyprland.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      ];

      # extra-substituters = [
      # ];
      # extra-trusted-public-keys = [
      # ];
    };

    # garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  # cleans nix-shell gc stuff
  services.angrr = {
    enable = true;
    settings.period = "7d";
  };

  environment.variables.LD_LIBRARY_PATH = lib.mkForce [
    "/run/current-system/sw/lib"
  ];
  environment.variables.NIX_REMOTE = "daemon";
}
