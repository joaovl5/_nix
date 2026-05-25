{
  mylib,
  config,
  inputs,
  pkgs,
  ...
}: let
  my = mylib.use config;
  o = my.options;
  u = my.units;
  inherit (o) t;
  local_packages = import ../../../packages {inherit pkgs inputs;};
  install_tubifarry_plugin = pkgs.writeShellScript "install-tubifarry-plugin" ''
    set -euo pipefail

    plugin_root="${config.nixarr.lidarr.stateDir}/plugins"
    owner_dir="$plugin_root/TypNull"
    target_dir="$owner_dir/Tubifarry"
    source_dir="${local_packages.tubifarry}/share/lidarr/plugins/TypNull/Tubifarry"

    ${pkgs.coreutils}/bin/install -d -m 0750 -o lidarr -g media "$plugin_root" "$owner_dir"
    ${pkgs.coreutils}/bin/rm -rf -- "$target_dir"
    ${pkgs.coreutils}/bin/install -d -m 0750 -o lidarr -g media "$target_dir"
    ${pkgs.coreutils}/bin/cp -R -- "$source_dir"/. "$target_dir"/
    ${pkgs.coreutils}/bin/chown -R lidarr:media "$target_dir"
    ${pkgs.coreutils}/bin/chmod -R u=rwX,g=rX,o= "$target_dir"
  '';
in
  o.module "unit.nixarr" (with o; {
    enable = toggle "Enable -arr services" false;
    vpn = {
      enable = toggle "Enable vpn client for -arr services" false;
    };
    flaresolverr = {
      enable = toggle "Enable flaresolverr" true;
    };
    torrent = {
      peer_port = opt "Peer port for torrent connections, set to forwarded port of VPN if using one." t.int 55055;
    };
    jellyfin = {
      endpoint = u.endpoint {
        port = 8096;
        target = "jellyfin";
      };
    };
    # indexing
    prowlarr = {
      endpoint = u.endpoint {
        port = 55057;
        target = "prowlarr";
      };
    };
    # music
    lidarr = {
      endpoint = u.endpoint {
        port = 55058;
        target = "lidarr";
      };
    };
    # movies
    radarr = {
      endpoint = u.endpoint {
        port = 55059;
        target = "radarr";
      };
    };
    # series
    sonarr = {
      endpoint = u.endpoint {
        port = 55060;
        target = "sonarr";
      };
    };
    # subs
    bazarr = {
      endpoint = u.endpoint {
        port = 55061;
        target = "bazarr";
      };
    };
  }) {imports = _: [inputs.nixarr.nixosModules.default];} (opts: (o.when opts.enable {
    my.vhosts = {
      jellyfin = {inherit (opts.jellyfin.endpoint) target sources;};
      prowlarr = {inherit (opts.prowlarr.endpoint) target sources;};
      lidarr = {inherit (opts.lidarr.endpoint) target sources;};
      radarr = {inherit (opts.radarr.endpoint) target sources;};
      sonarr = {inherit (opts.sonarr.endpoint) target sources;};
      bazarr = {inherit (opts.bazarr.endpoint) target sources;};
    };

    nixarr = {
      enable = true;

      vpn = {
        inherit (opts.vpn) enable;
      };
      # Torrents
      transmission = {
        enable = false;
      };

      # Jellyfin
      jellyfin = {
        enable = true;
      };

      # -arrs
      lidarr = {
        enable = true;
        inherit (opts.lidarr.endpoint) port;
        package = local_packages.lidarr-plugins;
      };

      radarr = {
        enable = true;
        inherit (opts.radarr.endpoint) port;
      };

      sonarr = {
        enable = true;
        inherit (opts.sonarr.endpoint) port;
      };

      prowlarr = {
        enable = true;
        inherit (opts.prowlarr.endpoint) port;
      };

      bazarr = {
        enable = true;
        inherit (opts.bazarr.endpoint) port;
      };
    };

    systemd.services.lidarr-install-tubifarry = {
      description = "Install the Tubifarry Lidarr plugin";
      before = ["lidarr.service"];
      requiredBy = ["lidarr.service"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = install_tubifarry_plugin;
      };
    };


    services = {
      flaresolverr = {
        inherit (opts.flaresolverr) enable;
      };
      jellyfin = {
      };
    };
  }))
