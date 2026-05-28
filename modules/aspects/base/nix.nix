_: {
  den.aspects.base-nix.meta.collisionPolicy = "class-wins";
  den.aspects.base-nix.nixos = {
    lib,
    config,
    system,
    mylib,
    ...
  }: let
    cfg = config.my.nix;
    o = (mylib.use config).options;
    host_system = system;
    is_darwin = lib.hasSuffix "darwin" host_system;
  in
    o.module "nix" (with o; {
      x86 = {
        enable = toggle "Enable x86_64 Linux specific Nix settings" (host_system == "x86_64-linux");
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
                max-jobs = 12;
                cores = 12;
                # http3 = true;
                http2 = true;
                http-connections = 50;
                experimental-features = [
                  "nix-command"
                  "flakes"
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
      ]);
}
