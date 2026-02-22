{
  nx = {
    pkgs,
    config,
    ...
  }: {
    systemd.timers."refresh-nps-cache" = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
        Unit = "refresh-nps-cache.service";
      };
    };

    systemd.services."refresh-nps-cache" = {
      path = ["/run/current-system/sw/"];
      serviceConfig = {
        Type = "oneshot";
        User = config.my.nix.username;
      };
      script = ''
        set -eu
        echo "Start refreshing nps cache..."
        # ⚠️ note the use of overlay (as described above), adjust if needed
        # ⚠️ use `nps -dddd -e -r` if you use flakes
        ${pkgs.nps}/bin/nps -dddd -e -r
        echo "... finished nps cache with exit code $?."
      '';
    };
  };
  hm = {
    nixos_config,
    nixos_options,
    lib,
    pkgs,
    inputs,
    options,
    config,
    ...
  }: let
    inherit (lib) mkMerge mkIf;
    cfg = nixos_config.my.nix;
  in {
    imports = [
      inputs.optnix.homeModules.optnix
    ];
    programs = {
      # better nix cli
      nh = mkMerge [
        {
          enable = true;
          clean.enable = true;
          clean.extraArgs = "--keep 5 --keep-since 5d";
        }
        (mkIf (cfg.flake_location != null) {
          flake = cfg.flake_location;
        })
      ];

      # indexing of nixpkgs
      nix-index = {
        enable = true;
      };

      # handling direnv w/ nix integrations
      direnv = {
        enable = true;
        nix-direnv.enable = true;
      };

      # options search
      optnix = let
        optnix_lib = inputs.optnix.mkLib pkgs;
      in {
        enable = true;
        settings = {
          scopes."nx" = {
            description = "NixOS";
            options-list-file = optnix_lib.mkOptionsList {
              options = nixos_options;
            };
          };
          scopes."hm" = {
            description = "Home-Manager";
            evaluator = "";
            options-list-file = optnix_lib.mkOptionsList {
              inherit options;
              transform = o:
                o
                // {
                  name = lib.removePrefix "home-manager.users.${config.home.username}." o.name;
                };
            };
          };
        };
      };
    };

    # faster direnv
    services.lorri = {
      enable = true;
    };

    home.packages = with pkgs; [
      # runs software without installing
      comma
      # search packages
      nps
      # edit flake inputs
      flake-edit
    ];
  };
}
