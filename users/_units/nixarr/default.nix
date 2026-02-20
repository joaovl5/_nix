{
  mylib,
  config,
  inputs,
  ...
}: let
  my = mylib.use config;
  o = my.options;
  inherit (o) t;
in
  {
    imports = [
      inputs.nixarr.nixosModules.default
    ];
  }
  // o.module "unit.nixarr" (with o; {
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
      host_ip = opt "Host IP (used for DNS)" t.str "127.0.0.1";
      host = opt "Host domain (used for DNS)" t.str "jellyfin.lan";
      port = opt "Port for Jellyfin" t.int 8096;
    };
    # indexing
    prowlarr = {
      port = opt "Port for Prowlarr" t.int 55057;
      host = opt "Host domain (used for DNS)" t.str "prowlarr.lan";
      host_ip = opt "Host IP (used for DNS)" t.str "127.0.0.1";
    };
    # music
    lidarr = {
      port = opt "Port for Lidarr" t.int 55058;
      host = opt "Host domain (used for DNS)" t.str "lidarr.lan";
      host_ip = opt "Host IP (used for DNS)" t.str "127.0.0.1";
    };
    # movies
    radarr = {
      port = opt "Port for Radarr" t.int 55059;
      host = opt "Host domain (used for DNS)" t.str "radarr.lan";
      host_ip = opt "Host IP (used for DNS)" t.str "127.0.0.1";
    };
    # series
    sonarr = {
      port = opt "Port for Sonarr" t.int 55060;
      host = opt "Host domain (used for DNS)" t.str "sonarr.lan";
      host_ip = opt "Host IP (used for DNS)" t.str "127.0.0.1";
    };
    # subs
    bazarr = {
      port = opt "Port for Bazarr" t.int 55061;
      host = opt "Host domain (used for DNS)" t.str "bazarr.lan";
      host_ip = opt "Host IP (used for DNS)" t.str "127.0.0.1";
    };
  }) {} (opts: (o.when opts.enable {
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
        # inherit (opts.jellyfin) port;
      };

      # -arrs
      lidarr = {
        enable = true;
        inherit (opts.lidarr) port;
      };

      radarr = {
        enable = true;
        inherit (opts.radarr) port;
      };

      sonarr = {
        enable = true;
        inherit (opts.sonarr) port;
      };

      prowlarr = {
        enable = true;
        inherit (opts.prowlarr) port;
      };

      bazarr = {
        enable = true;
        inherit (opts.bazarr) port;
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
