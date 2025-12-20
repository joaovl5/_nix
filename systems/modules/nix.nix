{lib, ...}: {
  nix = {
    generateRegistryFromInputs = lib.mkDefault true;
    settings = {
      warn-dirty = false;
      experimental-features = ["nix-command" "flakes" "ca-derivations"];
      download-buffer-size = lib.mkDefault 524288000; # 500mb
      substituters = [
        "https://nix-community.cachix.org"
      ];
      extra-substituters = [
        "https://cache.nixos.org/"
        "https://cache.garnix.io"
      ];
      extra-trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
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
