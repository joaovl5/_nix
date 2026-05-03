{
  lib,
  pkgs,
  config,
  mylib,
  ...
}: let
  cfg = config.my.nix;
  o = (mylib.use config).options;
  is_darwin = pkgs.stdenv.hostPlatform.isDarwin;
in
  o.module "nix" (with o; {
    x86 = {
      enable = toggle "Enable x86_64 Linux specific Nix settings" (pkgs.stdenv.hostPlatform.system == "x86_64-linux");
    };
  }) {} (opts:
    o.merge [
      {
        nixpkgs.config.allowUnfree = true;
        nix =
          {
            settings = {
              trusted-users = [cfg.username];
              warn-dirty = false;
              builders-use-substitutes = true;
              auto-optimise-store = true;
              # Prevent heavyweight local builds (Firefox/Rust LTO, CUDA) from exhausting RAM.
              max-jobs = 1;
              cores = 4;
              experimental-features = [
                "nix-command"
                "flakes"
                "pipe-operator" # if not using lix, is `pipe-operators`
                "flake-self-attrs" # used for some projects using submodules
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
            };

            gc =
              {
                automatic = true;
                options = "--delete-older-than 7d";
              }
              // (
                if is_darwin
                then {
                  interval = {
                    Weekday = 0;
                    Hour = 3;
                    Minute = 0;
                  };
                }
                else {
                  dates = "weekly";
                }
              );
          }
          // lib.optionalAttrs (!is_darwin) {
            daemonCPUSchedPolicy = lib.mkDefault (
              if cfg.is_server
              then "batch"
              else "idle"
            );
          };

        environment.variables.NIX_REMOTE = "daemon";
      }

      (o.when (!is_darwin) {
        services.angrr = {
          enable = true;
          settings.period = "7d";
        };

        # environment.variables.LD_LIBRARY_PATH = lib.mkForce [
        #   "/run/current-system/sw/lib"
        # ];
      })

      (o.when (!is_darwin && opts.x86.enable) {
        boot.binfmt.emulatedSystems = ["aarch64-linux"];
        nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      })
    ])
