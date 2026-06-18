_: {
  den.aspects.server.nixos = {
    mylib,
    config,
    globals,
    pkgs,
    lib,
    ...
  }: let
    my = mylib.use config;
    o = my.options;
    s = my.secrets;
    u = my.units;
    inherit (o) t;

    inherit (globals.dns) tld;

    elixir = (pkgs.formats.elixirConf {}).lib;
    cfg = config.services.akkoma;
    erl_dist_address = "{${lib.concatStringsSep "," (lib.splitString "." cfg.dist.address)}}";
    akkoma_ctl_env = pkgs.writeShellScript "akkoma-ctl-env" ''
      cd ${cfg.package}

      runtime_directory="''${RUNTIME_DIRECTORY:-/run/akkoma}"
      export CACHE_DIRECTORY="''${CACHE_DIRECTORY:-/var/cache/akkoma}"
      export AKKOMA_CONFIG_PATH="''${runtime_directory%%:*}/config.exs"
      export ERL_EPMD_ADDRESS="${cfg.dist.address}"
      export ERL_EPMD_PORT="${toString cfg.dist.epmdPort}"
      export ERL_FLAGS="-kernel inet_dist_use_interface ${erl_dist_address} -kernel inet_dist_listen_min ${toString cfg.dist.portMin} -kernel inet_dist_listen_max ${toString cfg.dist.portMax}"
      export RELEASE_COOKIE="$(<"''${runtime_directory%%:*}/cookie")"
      export RELEASE_NAME="akkoma"

      exec ${cfg.package}/bin/pleroma_ctl "$@"
    '';
    pleroma_ctl = pkgs.writeShellApplication {
      name = "pleroma_ctl";
      text = ''
        if [ "''${1-}" = "update" ]; then
          echo "OTP releases are not supported on NixOS." >&2
          exit 64
        fi

        exec ${config.systemd.package}/bin/run0 --user=${cfg.user} ${akkoma_ctl_env} "$@"
      '';
    };
  in
    o.module "unit.akkoma" (with o; {
      enable = toggle "Enable Akkoma" false;
      endpoint = u.endpoint {
        port = 4010;
        target = "i";
      };
      upload_dir = opt "Directory where Akkoma stores uploads." t.str "/var/lib/akkoma/uploads";
      static_dir = opt "Directory where Akkoma stores mutable static files." t.str "/var/lib/akkoma/static";
      instance = {
        name = opt "Instance name." t.str "i.trll.ing";
        description = opt "Instance description." t.str "le trll";
        email = optional "Instance administrator email." t.str {};
        upload_limit_bytes = opt "Maximum upload size in bytes." t.int (100 * 1024 * 1024);
        registrations_open = toggle "Allow open registrations." false;
        invites_enabled = toggle "Enable invitation-based registration." true;
        federating = toggle "Enable federation." true;
      };
    }) {} (opts:
      o.when opts.enable (let
        db_name = "akkoma";
        db_user = "akkoma";
        domain = "${opts.endpoint.target}.${tld}";
        secret_file = "${s.dir}/akkoma.yaml";
        frontend_setup_script = lib.concatStringsSep "\n" (
          lib.mapAttrsToList
          (_: frontend: ''
            install -d -m 0755 -o ${cfg.user} -g ${cfg.group} ${lib.escapeShellArg "${opts.static_dir}/frontends/${frontend.name}"}
            target=${lib.escapeShellArg "${opts.static_dir}/frontends/${frontend.name}/${frontend.ref}"}
            if [ -e "$target" ] && [ ! -L "$target" ]; then
              echo "Leaving existing non-symlink Akkoma frontend at $target"
            else
              ln -sfn ${lib.escapeShellArg "${frontend.package}"} "$target"
            fi
          '')
          cfg.frontends
        );
      in {
        assertions = [
          {
            assertion = config.my."unit.postgres".enable;
            message = "unit.akkoma requires unit.postgres.enable = true";
          }
          {
            assertion = config.my."unit.traefik".enable;
            message = "unit.akkoma requires unit.traefik.enable = true";
          }
          {
            assertion = opts.instance.email != null;
            message = "unit.akkoma.instance.email must be set explicitly";
          }
        ];

        my = {
          vhosts.akkoma = {
            inherit (opts.endpoint) target sources;
          };

          "unit.postgres".databases = lib.mkAfter [
            {
              name = db_name;
              password = s.secret_path "akkoma_postgres_password";
            }
          ];

          "unit.akkoma".backup.items = {
            postgres = {
              kind = "postgres_dump";
              policy = "critical_infra";
              run_as_user = "postgres";
              postgres_dump.database = db_name;
            };
            uploads = {
              kind = "path";
              policy = "sensitive_data";
              path.paths = [opts.upload_dir];
            };
            static = {
              kind = "path";
              policy = "sensitive_data";
              path.paths = [opts.static_dir];
            };
          };
        };

        sops.secrets = {
          akkoma_postgres_password = s.mk_secret secret_file "postgres_password" {};
          akkoma_release_cookie = s.mk_secret secret_file "release_cookie" {};
          akkoma_secret_key_base = s.mk_secret secret_file "secret_key_base" {};
          akkoma_signing_salt = s.mk_secret secret_file "signing_salt" {};
          akkoma_liveview_signing_salt = s.mk_secret secret_file "liveview_signing_salt" {};
          akkoma_jwt_signer = s.mk_secret secret_file "jwt_signer" {};
          akkoma_vapid_public = s.mk_secret secret_file "vapid_public" {};
          akkoma_vapid_private = s.mk_secret secret_file "vapid_private" {};
        };

        services.akkoma = {
          enable = true;
          nginx = null;
          installWrapper = false;
          initSecrets = false;

          initDb.enable = false;

          dist.cookie._secret = s.secret_path "akkoma_release_cookie";

          extraPackages = with pkgs; [
            exiftool
            ffmpeg-headless
            imagemagick
          ];

          config = {
            ":pleroma" = {
              ":configurable_from_database" = true;

              ":instance" = {
                inherit
                  (opts.instance)
                  name
                  description
                  email
                  registrations_open
                  invites_enabled
                  federating
                  ;
                inherit (opts) static_dir upload_dir;
                upload_limit = opts.instance.upload_limit_bytes;
              };

              "Pleroma.Repo" = {
                adapter = elixir.mkRaw "Ecto.Adapters.Postgres";
                hostname = "127.0.0.1";
                port = 5432;
                username = db_user;
                database = db_name;
                password._secret = s.secret_path "akkoma_postgres_password";
              };

              "Pleroma.Web.Endpoint" = {
                url = {
                  host = domain;
                  scheme = "https";
                  port = 443;
                };
                http = {
                  ip = "127.0.0.1";
                  inherit (opts.endpoint) port;
                };
                secret_key_base._secret = s.secret_path "akkoma_secret_key_base";
                signing_salt._secret = s.secret_path "akkoma_signing_salt";
                live_view.signing_salt._secret = s.secret_path "akkoma_liveview_signing_salt";
              };

              "Pleroma.Upload" = {
                base_url = "https://${domain}/media/";
                filters = map elixir.mkRaw [
                  "Pleroma.Upload.Filter.Exiftool"
                  "Pleroma.Upload.Filter.Dedupe"
                  "Pleroma.Upload.Filter.AnonymizeFilename"
                ];
              };

              ":media_proxy".enabled = false;
            };

            ":joken".":default_signer"._secret = s.secret_path "akkoma_jwt_signer";
            ":web_push_encryption".":vapid_details" = {
              subject = "mailto:${opts.instance.email}";
              public_key._secret = s.secret_path "akkoma_vapid_public";
              private_key._secret = s.secret_path "akkoma_vapid_private";
            };
          };
        };

        environment.systemPackages = [pleroma_ctl];
        systemd.services.akkoma = {
          requires = ["akkoma-static-setup.service"];
          after = ["akkoma-static-setup.service"];
          serviceConfig = {
            BindPaths = lib.mkAfter ["${opts.static_dir}:${opts.static_dir}:norbind"];
            BindReadOnlyPaths = lib.mkForce [];
          };
        };

        systemd.services.akkoma-static-setup = {
          description = "Prepare mutable Akkoma static directory";
          requiredBy = ["akkoma.service"];
          before = ["akkoma.service"];
          path = [pkgs.coreutils];
          serviceConfig = {
            Type = "oneshot";
            User = "root";
          };
          script = ''
            install -d -m 0755 -o ${cfg.user} -g ${cfg.group} ${lib.escapeShellArg opts.static_dir}
            install -d -m 0755 -o ${cfg.user} -g ${cfg.group} ${lib.escapeShellArg "${opts.static_dir}/frontends"}
            install -d -m 0755 -o ${cfg.user} -g ${cfg.group} ${lib.escapeShellArg "${opts.static_dir}/instance"}

            ${frontend_setup_script}
          '';
        };

        systemd.services.akkoma-initdb = {
          description = "Akkoma social network database setup";
          requiredBy = ["akkoma.service"];
          requires = [
            "akkoma-config.service"
            "postgresql.service"
            "postgresql-password-sync.service"
          ];
          after = [
            "akkoma-config.service"
            "postgresql.service"
            "postgresql-password-sync.service"
          ];
          before = ["akkoma.service"];
          path = [config.services.postgresql.package];
          serviceConfig = {
            Type = "oneshot";
            User = "postgres";
            RemainAfterExit = true;
          };
          script = ''
            psql -d ${db_name} -v ON_ERROR_STOP=1 <<'SQL'
              CREATE EXTENSION IF NOT EXISTS citext;
              CREATE EXTENSION IF NOT EXISTS pg_trgm;
              CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
            SQL
          '';
        };
      }));
}
