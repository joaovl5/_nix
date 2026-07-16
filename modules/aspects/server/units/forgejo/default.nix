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
    u = my.units;
    s = my.secrets;

    inherit (globals.dns) tld;
  in
    o.module "unit.forgejo" (with o; {
      enable = toggle "Enable Forgejo" false;
      actions_runner = {
        enable = toggle "Enable Forgejo Actions runner" false;
        uuid = optional "Forgejo Actions runner UUID" t.str {};
        capacity = opt "Maximum concurrent Forgejo Actions jobs" t.ints.positive 1;
        timeout = opt "Maximum Forgejo Actions job runtime" t.str "3h";
        shutdown_timeout = opt "Maximum runner shutdown wait for active jobs" t.str "30m";
      };
      omp_updater_runner = {
        enable = toggle "Enable the repository-scoped OMP updater runner" false;
        uuid = optional "OMP updater runner UUID" t.str {};
        capacity = opt "Maximum concurrent OMP updater jobs" t.ints.positive 1;
        timeout = opt "Maximum OMP updater job runtime" t.str "3h";
        shutdown_timeout = opt "Maximum OMP runner shutdown wait for active jobs" t.str "30m";
      };
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
        runner_user = "forgejo-runner";
        runner_state_dir = "/var/lib/${runner_user}";
        runner_config = (pkgs.formats.yaml {}).generate "forgejo-runner.yaml" {
          log.level = "info";
          runner = {
            inherit (opts.actions_runner) capacity timeout shutdown_timeout;
          };
          cache = {
            enabled = true;
            dir = "${runner_state_dir}/cache";
          };
          container.docker_host = "automount";
          container.force_pull = true;
          server.connections.forgejo = {
            url = "https://${opts.web.endpoint.target}.${tld}/";
            inherit (opts.actions_runner) uuid;
            token_url = "file:$CREDENTIALS_DIRECTORY/token.txt";
            labels = [
              "ubuntu-latest:docker://node:20-bookworm"
              "debian-latest:docker://node:20-bookworm"
            ];
          };
        };
        omp_runner_user = "forgejo-runner-omp-updater";
        omp_runner_state_dir = "/var/lib/${omp_runner_user}";
        omp_runner_config = (pkgs.formats.yaml {}).generate "forgejo-omp-updater-runner.yaml" {
          log.level = "info";
          runner = {
            inherit (opts.omp_updater_runner) capacity timeout shutdown_timeout;
          };
          cache = {
            enabled = true;
            dir = "${omp_runner_state_dir}/cache";
          };
          server.connections.forgejo = {
            url = "https://${opts.web.endpoint.target}.${tld}/";
            inherit (opts.omp_updater_runner) uuid;
            token_url = "file:$CREDENTIALS_DIRECTORY/token.txt";
            labels = ["nix:host"];
          };
        };
      in
        lib.mkMerge [
          {
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
          }
          (lib.mkIf opts.actions_runner.enable {
            assertions = [
              {
                assertion = opts.actions_runner.uuid != null;
                message = "unit.forgejo.actions_runner.uuid must be set when the runner is enabled";
              }
            ];

            virtualisation.docker.enable = true;

            sops.secrets.forgejo_actions_runner_token =
              s.mk_secret "${s.dir}/forgejo.yaml" "actions_runner_token" {};

            users.groups.${runner_user} = {};
            users.users.${runner_user} = {
              isSystemUser = true;
              group = runner_user;
              home = runner_state_dir;
              extraGroups = ["docker"];
            };

            systemd.services.forgejo-runner = {
              description = "Forgejo Actions runner";
              wantedBy = ["multi-user.target"];
              after = ["docker.service" "network-online.target"];
              wants = ["network-online.target"];
              requires = ["docker.service"];
              environment.HOME = runner_state_dir;
              serviceConfig = {
                User = runner_user;
                Group = runner_user;
                StateDirectory = runner_user;
                WorkingDirectory = runner_state_dir;
                LoadCredential = "token.txt:${s.secret_path "forgejo_actions_runner_token"}";
                ExecStart = "${lib.getExe pkgs.forgejo-runner} daemon --config ${runner_config}";
                Restart = "on-failure";
                RestartSec = "5s";
              };
            };
          })
          (lib.mkIf opts.omp_updater_runner.enable {
            assertions = [
              {
                assertion = opts.omp_updater_runner.uuid != null;
                message = "unit.forgejo.omp_updater_runner.uuid must be set when the runner is enabled";
              }
            ];

            sops.secrets.forgejo_omp_updater_runner_token =
              s.mk_secret "${s.dir}/forgejo.yaml" "omp_updater_runner_token" {};

            users.groups.${omp_runner_user} = {};
            users.users.${omp_runner_user} = {
              isSystemUser = true;
              group = omp_runner_user;
              home = omp_runner_state_dir;
            };

            systemd.services.forgejo-omp-updater-runner = {
              description = "Repository-scoped OMP Forgejo Actions runner";
              wantedBy = ["multi-user.target"];
              after = ["network-online.target" "nix-daemon.service"];
              wants = ["network-online.target"];
              path = [
                pkgs.bash
                pkgs.coreutils
                pkgs.git
                pkgs.gnutar
                pkgs.nodejs_24
                config.nix.package
              ];
              environment = {
                HOME = omp_runner_state_dir;
                SHELL = lib.getExe pkgs.bash;
                SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
              };
              serviceConfig = {
                User = omp_runner_user;
                Group = omp_runner_user;
                StateDirectory = omp_runner_user;
                WorkingDirectory = omp_runner_state_dir;
                LoadCredential = "token.txt:${s.secret_path "forgejo_omp_updater_runner_token"}";
                ExecStart = "${lib.getExe pkgs.forgejo-runner} daemon --config ${omp_runner_config}";
                Restart = "on-failure";
                RestartSec = "5s";
                UMask = "0077";
                CapabilityBoundingSet = "";
                LockPersonality = true;
                NoNewPrivileges = true;
                PrivateDevices = true;
                PrivateTmp = true;
                ProtectControlGroups = true;
                ProtectHome = true;
                ProtectKernelModules = true;
                ProtectKernelTunables = true;
                ProtectSystem = "strict";
                RestrictSUIDSGID = true;
              };
            };
          })
        ]));
}
