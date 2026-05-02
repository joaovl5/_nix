{
  mylib,
  config,
  globals,
  pkgs,
  ...
}: let
  my = mylib.use config;
  o = my.options;
  u = my.units;

  inherit (globals.dns) tld;
in
  o.module "unit.forgejo" (with o; {
    enable = toggle "Enable Forgejo" false;
    web = {
      endpoint = u.endpoint {
        port = 60906;
        target = "git";
      };
    };
  }) {} (opts:
    o.when opts.enable (let
      source_data_dir = "/var/lib/forgejo";
      pkg = pkgs.forgejo;
    in {
      my = {
        vhosts.forgejo = {
          inherit (opts.web.endpoint) target sources;
        };

        tcp_routes.forgejo_ssh = {
          listen.port = 22;
          upstreams = ["127.0.0.1:4220"];
          rule = "HostSNI(`*`)";
        };

        "unit.forgejo".backup.items.state = {
          kind = "path";
          policy = "critical_infra";
          path = {
            paths = [source_data_dir];
          };
        };
      };

      services.forgejo = {
        enable = true;
        package = pkg;
        stateDir = source_data_dir;
        settings = {
          session.COOKIE_SECURE = true;
          server = with opts.web.endpoint; rec {
            HTTP_PORT = port;
            DOMAIN = "${target}.${tld}";
            ROOT_URL = "https://${DOMAIN}/";

            START_SSH_SERVER = true;
            BUILTIN_SSH_SERVER_USER = "git";
            SSH_PORT = 22;
            SSH_LISTEN_HOST = "127.0.0.1";
            SSH_LISTEN_PORT = 4220;
          };
        };
      };
    }))
