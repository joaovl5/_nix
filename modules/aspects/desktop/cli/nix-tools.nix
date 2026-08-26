_: {
  den.aspects.cli.homeManager = {
    nixos_config,
    lib,
    pkgs,
    inputs,
    system,
    ...
  }: let
    inherit (lib) mkMerge mkIf;
    cfg = nixos_config.my.nix;
  in {
    programs = {
      # better nix cli
      nh = mkMerge [
        {
          enable = true;
          clean.enable = true;
          clean.extraArgs = "--keep 5 --keep-since 5d";
        }
        (mkIf (cfg.repo_location != null) {
          flake = cfg.repo_location;
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

      nix-search-tv = {
        enable = true;
        settings = {
          indexes = ["nixpkgs" "nixos" "home-manager" "noogle" "nur"];
        };
      };

      nix-your-shell = {
        enable = true;
        nix-output-monitor.enable = true;
        enableFishIntegration = true;
        enableNushellIntegration = true;
      };

      nix-init = {
        enable = true;
        settings = {
          nixpkgs = "nixpkgs";
          commit = "true";
          maintainers = ["lav"];
        };
      };
    };

    home.shellAliases = {
      "+s" = "nh os switch --elevation-program run0 --diff always";
      "+S" = "+n --show-trace --verbose";
      "+d" = "deploy";
      "+D" = "deploy --skip-checks";
      "+c" = "nh clean all --elevation-program run0";
      "+ea" = "direnv allow";
      "+er" = "direnv reload";
      "?" = "tv nix-search-tv";
    };

    # faster direnv
    services.lorri = {
      enable = true;
    };

    home.packages = with pkgs; [
      # deploy-rs
      inputs.deploy-rs.packages.${system}.default
      # runs software without installing
      comma
      # search packages
      nps
      # manage source pins
      npins
      # better 'nix' with pretty things
      nix-output-monitor
      # inspect things
      nix-du
      nix-diff
      dix
      nvd
      nix-tree
      # do some things
      nix-update
      nurl
    ];
  };
  den.aspects.cli.nixos = {
    pkgs,
    config,
    ...
  }: {
    documentation.nixos.options.warningsAreErrors = false;

    services = {
      angrr = {
        enable = true;
        settings = {
          temporary-root-policies = {
            direnv = {
              path-regex = "/\\.direnv/";
              period = "3d";
            };
            result = {
              path-regex = "result[^/]*$";
              period = "3d";
            };
          };
          profile-policies.system = {
            profile-paths = ["/nix/var/nix/profiles/system"];
            keep-since = "14d";
            keep-latest-n = 5;
          };
        };
      };
    };

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
}
