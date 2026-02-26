{
  mylib,
  config,
  inputs,
  ...
}: let
  my = mylib.use config;
  o = my.options;
  u = my.units;
  inherit (o) t;
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
        enable = true;
        vpn.enable = opts.vpn.enable;
        peerPort = opts.torrent.peer_port;
      };

      # Jellyfin
      jellyfin = {
        enable = true;
      };

      # -arrs
      lidarr = {
        enable = true;
        inherit (opts.lidarr.endpoint) port;
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

    services = {
      flaresolverr = {
        inherit (opts.flaresolverr) enable;
      };
      jellyfin = {
      };
    };
  }))
