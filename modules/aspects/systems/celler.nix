{
  den.aspects = {
    celler-cache-client.nixos = {
      globals,
      lib,
      ...
    }: let
      cache_url = "https://cache.${globals.dns.tld}/main";
    in {
      nix.settings = {
        substituters = lib.mkBefore [cache_url];
        trusted-substituters = [cache_url];
        trusted-public-keys = [globals.hosts.tyrant.celler.cache_public_key];
      };
    };

    tyrant-celler.nixos = {
      config,
      globals,
      inputs,
      lib,
      mylib,
      pkgs,
      ...
    }: let
      s = (mylib.use config).secrets;
      cache_domain = "cache.${globals.dns.tld}";
      api_endpoint = "https://${cache_domain}/";
      jwt_public_key_file = pkgs.writeText "celler-jwt-public-key.pem" globals.hosts.tyrant.celler.jwt_public_key;
      watcher_token = config.sops.secrets.celler_watcher_token.path;
      watcher_config = (pkgs.formats.toml {}).generate "celler-config.toml" {
        default-server = "local";
        servers.local = {
          endpoint = "http://127.0.0.1:8080";
          token-file = watcher_token;
        };
      };
    in {
      imports = [inputs.celler.nixosModules.cellerd];

      sops.secrets.celler_watcher_token = s.mk_secret "${s.dir}/celler.yaml" "watcher_token" {};

      services.cellerd = {
        enable = true;
        settings = {
          listen = "127.0.0.1:8080";
          allowed-hosts = [cache_domain "127.0.0.1:8080"];
          api-endpoint = api_endpoint;
          substituter-endpoint = api_endpoint;
          database.url = "sqlite:///var/lib/cellerd/server.db?mode=rwc";
          storage = {
            type = "local";
            path = "/var/lib/cellerd/storage";
          };
          chunking = {
            nar-size-threshold = 64 * 1024;
            min-size = 16 * 1024;
            avg-size = 64 * 1024;
            max-size = 256 * 1024;
          };
          garbage-collection.default-retention-period = "30d";
          jwt.rs256-public-key-file = jwt_public_key_file;
        };
      };

      my.vhosts.celler-cache = {
        target = "cache";
        sources = ["http://127.0.0.1:8080"];
      };

      environment.systemPackages = [pkgs.celler];

      environment.etc."celler/config.toml".source = watcher_config;

      systemd.services.celler-watch-store = {
        description = "Push new Nix store paths to Celler";
        wantedBy = ["multi-user.target"];
        after = ["cellerd.service" "nix-daemon.service"];
        requires = ["cellerd.service"];
        serviceConfig = {
          ExecStart = "${lib.getExe pkgs.celler} watch-store main";
          Environment = "XDG_CONFIG_HOME=/etc";
          Restart = "on-failure";
          RestartSec = 10;
        };
      };
    };
  };
}
