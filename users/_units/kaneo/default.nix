{
  mylib,
  config,
  globals,
  inputs,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkOption;
  local_packages = import ../../../packages {inherit pkgs inputs;};

  my = mylib.use config;
  o = my.options;
  s = my.secrets;
  u = my.units;

  inherit (globals.dns) tld;
in
  o.module "unit.kaneo" (with o; {
    enable = toggle "Enable Kaneo" false;
    package = mkOption {
      description = "Kaneo package to run";
      type = lib.types.package;
      default = local_packages.kaneo;
    };
    web = {
      endpoint = u.endpoint {
        port = 5173;
        target = "kaneo";
      };
    };
    api = {
      endpoint = u.endpoint {
        port = 1337;
        target = "api.kaneo";
      };
    };
  }) {} (opts:
    o.when opts.enable (let
      user = "kaneo";
      group = "kaneo";
      db_name = "kaneo";
      pkg = opts.package;
      client_url = "https://${opts.web.endpoint.target}.${tld}";
      api_url = "https://${opts.api.endpoint.target}.${tld}";
      api_workdir = "${pkg}/libexec/kaneo/apps/api";
      state_dir = "/var/lib/kaneo";
      web_runtime_root = "/run/kaneo-web";
      web_asset_root = "${web_runtime_root}/html";
      web_config_path = "${web_runtime_root}/nginx.conf";
      kaneo_secret_file = "${s.dir}/kaneo.yaml";

      prepare_web = pkgs.writeShellScript "prepare-kaneo-web" ''
        set -euo pipefail

        rm -rf ${web_asset_root}
        mkdir -p \
          ${web_asset_root} \
          ${web_runtime_root}/logs \
          ${web_runtime_root}/client_body_temp \
          ${web_runtime_root}/proxy_temp \
          ${web_runtime_root}/fastcgi_temp \
          ${web_runtime_root}/uwsgi_temp \
          ${web_runtime_root}/scgi_temp

        cp -a ${pkg}/share/kaneo/web/. ${web_asset_root}/
        chmod -R u+w ${web_asset_root}
        export KANEO_WEB_ASSET_ROOT=${web_asset_root}
        ${pkg}/share/kaneo/replace-web-env.sh

        cat > ${web_config_path} <<'EOF'
        pid ${web_runtime_root}/nginx.pid;
        error_log ${web_runtime_root}/logs/error.log notice;

        events {}

        http {
          include ${pkgs.nginx}/conf/mime.types;
          access_log ${web_runtime_root}/logs/access.log;
          client_body_temp_path ${web_runtime_root}/client_body_temp;
          proxy_temp_path ${web_runtime_root}/proxy_temp;
          fastcgi_temp_path ${web_runtime_root}/fastcgi_temp;
          uwsgi_temp_path ${web_runtime_root}/uwsgi_temp;
          scgi_temp_path ${web_runtime_root}/scgi_temp;

          server {
            listen 127.0.0.1:${toString opts.web.endpoint.port};
            listen [::1]:${toString opts.web.endpoint.port};
            server_name localhost;

            add_header X-Content-Type-Options "nosniff" always;
            add_header X-Frame-Options "SAMEORIGIN" always;
            add_header X-XSS-Protection "1; mode=block" always;
            add_header Referrer-Policy "strict-origin-when-cross-origin" always;

            gzip on;
            gzip_vary on;
            gzip_min_length 1000;
            gzip_proxied any;
            gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
            gzip_comp_level 6;

            location / {
              root ${web_asset_root};
              index index.html;
              try_files $uri $uri/ /index.html;
            }
          }
        }
        EOF
      '';

      start_api = pkgs.writeShellScript "kaneo-api-start" ''
                set -euo pipefail

                auth_secret="$(${pkgs.coreutils}/bin/cat ${s.secret_path "kaneo_auth_secret"})"
                postgres_password="$(${pkgs.coreutils}/bin/cat ${s.secret_path "kaneo_postgres_password"})"
                encoded_postgres_password="$(RAW_POSTGRES_PASSWORD="$postgres_password" ${pkgs.python3}/bin/python - <<'PY'
        import os
        import urllib.parse
        print(urllib.parse.quote(os.environ["RAW_POSTGRES_PASSWORD"], safe=""))
        PY
                )"

                export AUTH_SECRET="$auth_secret"
                export POSTGRES_PASSWORD="$postgres_password"
                export DATABASE_URL="postgresql://${db_name}:$encoded_postgres_password@127.0.0.1:5432/${db_name}"

                exec ${pkg}/bin/kaneo-api
      '';
    in {
      assertions = [
        {
          assertion = config.my."unit.postgres".enable;
          message = "unit.kaneo requires unit.postgres.enable = true";
        }
      ];

      my = {
        vhosts.kaneo = {
          inherit (opts.web.endpoint) target sources;
        };
        vhosts."kaneo-api" = {
          inherit (opts.api.endpoint) target sources;
        };
        "unit.postgres".databases = lib.mkAfter [
          {
            name = db_name;
            password = s.secret_path "kaneo_postgres_password";
          }
        ];
      };

      sops.secrets = {
        "kaneo_auth_secret" = s.mk_secret kaneo_secret_file "kaneo_auth_secret" {
          owner = user;
          inherit group;
        };
        "kaneo_postgres_password" = s.mk_secret kaneo_secret_file "kaneo_postgres_password" {
          owner = user;
          inherit group;
        };
      };

      users.users.${user} = {
        inherit group;
        home = state_dir;
        isSystemUser = true;
      };
      users.groups.${group} = {};

      systemd.services.kaneo-api = {
        description = "Kaneo API";
        wantedBy = ["multi-user.target"];
        after = ["postgresql.service" "postgresql-password-sync.service"];
        requires = ["postgresql.service" "postgresql-password-sync.service"];
        environment = {
          HOME = state_dir;
          NODE_ENV = "production";
          KANEO_API_PORT = toString opts.api.endpoint.port;
          KANEO_API_URL = api_url;
          KANEO_CLIENT_URL = client_url;
          CORS_ORIGINS = client_url;
          POSTGRES_DB = db_name;
          POSTGRES_USER = db_name;
        };
        serviceConfig = {
          Type = "simple";
          User = user;
          Group = group;
          WorkingDirectory = api_workdir;
          StateDirectory = "kaneo";
          Restart = "on-failure";
          RestartSec = "5s";
          ExecStart = start_api;
        };
      };

      systemd.services.kaneo-web = {
        description = "Kaneo web";
        wantedBy = ["multi-user.target"];
        path = with pkgs; [
          coreutils
          findutils
          gnugrep
          gnused
        ];
        environment = {
          HOME = state_dir;
          KANEO_API_URL = api_url;
          KANEO_CLIENT_URL = client_url;
          KANEO_WEB_RUNTIME_DIR = web_runtime_root;
          KANEO_WEB_CONFIG = web_config_path;
        };
        serviceConfig = {
          Type = "simple";
          User = user;
          Group = group;
          WorkingDirectory = web_runtime_root;
          RuntimeDirectory = "kaneo-web";
          StateDirectory = "kaneo";
          RuntimeDirectoryMode = "0750";
          Restart = "on-failure";
          RestartSec = "5s";
          ExecStartPre = [prepare_web];
          ExecStart = "${pkg}/bin/kaneo-web";
        };
      };
    }))
