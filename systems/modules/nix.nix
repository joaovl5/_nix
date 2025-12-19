{ lib, ... }:
{
  nix = {
    generateRegistryFromInputs = lib.mkDefault true;
    settings = {
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
  };

  environment.variables.LD_LIBRARY_PATH = lib.mkForce [
    "/run/current-system/sw/lib"
  ];
}
