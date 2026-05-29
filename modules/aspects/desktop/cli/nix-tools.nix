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

      # options search
      optnix = let
        options_list_cmd = scope: "nix eval --json --impure --file ${lib.escapeShellArg cfg.repo_location} _utils.optnix.${scope}";
      in {
        enable = true;
        settings = {
          scopes."nx" = {
            description = "NixOS";
            options-list-cmd = options_list_cmd "nx";
          };
          scopes."hj" = {
            description = "Hjem";
            evaluator = "";
            options-list-cmd = options_list_cmd "hj";
          };
          scopes."hm" = {
            description = "Home-Manager";
            evaluator = "";
            options-list-cmd = options_list_cmd "hm";
          };
        };
      };
    };

    home.shellAliases = {
      "+s" = "nh os switch --elevation-program run0 --diff always";
      "+S" = "+n --show-trace --verbose";
      "+d" = "deploy";
      "+D" = "deploy --skip-checks";
      "+c" = "nh clean all --elevation-program run0";
      "?" = "nps --color=always -e=true --truncate=true";
      "?nx" = "optnix -s nx";
      "?hm" = "optnix -s hm";
      "?hj" = "optnix -s hj";
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
    ];
  };
  den.aspects.cli.nixos = {
    pkgs,
    config,
    ...
  }: {
    documentation.nixos.options.warningsAreErrors = false;
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
