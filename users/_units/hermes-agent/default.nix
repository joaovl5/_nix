{
  mylib,
  config,
  pkgs,
  lib,
  ...
}: let
  my = mylib.use config;
  o = my.options;
  s = my.secrets;
  u = my.units;
  t = lib.types;

  inherit (lib) optionalAttrs;

  ContainerPrivateUsers = t.oneOf [
    t.int
    (t.enum [
      "no"
      "identity"
      "pick"
    ])
  ];

  default_sops_environment_file = "${s.dir}/hermes-agent.yaml";
  default_container_id = 30;
in
  o.module "unit.hermes-agent" (with o; {
    enable = toggle "Enable Hermes Agent native-container service" false;
    package = opt "Hermes Agent package." t.package pkgs.llm-agents.hermes-agent;
    state_dir = opt "Host directory for Hermes Agent container state." t.str "/var/lib/containers/hermes-agent/state";

    container = {
      name = opt "NixOS container name." t.str "hermes-agent";
      id = opt "Numeric ID used to derive default routed container addresses." t.int default_container_id;
      auto_start = toggle "Start the Hermes container at boot." true;
      private_users = opt "NixOS container privateUsers mode." ContainerPrivateUsers "identity";
      host_address = optional "Host-side veth IPv4 address." t.str {};
      local_address = optional "Container-side veth IPv4 address." t.str {};
    };

    nat = {
      enable = toggle "Enable host NAT for Hermes container outbound access." true;
      external_interface = optional "Host interface used for outbound NAT." t.str {};
    };

    hermes = {
      settings = opt "Non-secret Hermes config rendered to config.yaml." t.attrs {};
      environment_files = opt "Host env files bind-mounted read-only into the guest." (t.listOf t.str) [];
      sops_environment_file = {
        enable = toggle "Declare a sops-nix Hermes environment file secret and inject it into the guest." (builtins.pathExists default_sops_environment_file);
        name = opt "sops-nix secret name for the Hermes environment file." t.str "hermes_agent_env";
        file = opt "SOPS file containing the Hermes dotenv content." t.str default_sops_environment_file;
        key = opt "SOPS key containing the Hermes dotenv content." t.str "env";
      };
      extra_packages = opt "Extra packages added to the Hermes service PATH inside the guest." (t.listOf t.package) [];
      extra_args = opt "Extra arguments appended to `hermes gateway run`." (t.listOf t.str) [];
    };

    ingress = {
      dashboard = {
        enable = toggle "Expose the Hermes web dashboard through the host reverse proxy." false;
        port = opt "Hermes dashboard port inside the container." t.int 9119;
        target = opt "Dashboard reverse-proxy subdomain prefix." t.str "hermes";
        tui = toggle "Expose the dashboard in-browser Chat/TUI tab." true;
      };
      api = {
        enable = toggle "Expose the Hermes OpenAI-compatible API through the host reverse proxy." false;
        port = opt "Hermes API server port inside the container." t.int 8642;
        target = opt "API reverse-proxy subdomain prefix." t.str "hermes-api";
        cors_origins = opt "Browser origins allowed to call the Hermes API server directly." (t.listOf t.str) [];
      };
    };
  }) {} (opts:
    o.when opts.enable (let
      container_name = opts.container.name;
      container_veth = "ve-${container_name}";
      container_id = opts.container.id;
      host_address =
        if opts.container.host_address != null
        then opts.container.host_address
        else "10.88.${toString container_id}.1";
      local_address =
        if opts.container.local_address != null
        then opts.container.local_address
        else "10.88.${toString container_id}.2";

      guest_state_dir = "/var/lib/hermes";
      guest_hermes_home = "${guest_state_dir}/.hermes";
      guest_home_dir = "${guest_state_dir}/home";
      guest_workspace = "${guest_state_dir}/workspace";

      inherit (opts.ingress) dashboard;
      inherit (opts.ingress) api;
      api_cors_origins =
        if api.cors_origins != []
        then api.cors_origins
        else lib.optional dashboard.enable "https://${dashboard.target}.${config.my.dns.tld}";
      dashboard_web_dist = pkgs.buildNpmPackage {
        pname = "hermes-dashboard-web";
        version = opts.package.version or "0.12.0";
        src = opts.package.src + "/web";
        npmDepsHash = "sha256-HWB1piIPglTXbzQHXFYHLgVZIbDb60esupXSQGa1+lI=";
        installPhase = ''
          runHook preInstall
          mkdir -p "$out"
          cp -r ../hermes_cli/web_dist/. "$out/"
          runHook postInstall
        '';
      };

      default_settings = {
        terminal = {
          backend = "local";
          cwd = guest_workspace;
        };
      };
      hermes_settings = lib.recursiveUpdate default_settings opts.hermes.settings;
      config_yaml = u.write_yaml_from_attrset "hermes-agent-config.yaml" hermes_settings;

      guest_env_dir = "/run/hermes-agent/env";
      inherit (opts.hermes) sops_environment_file;
      sops_environment_files = lib.optional sops_environment_file.enable (s.secret_path sops_environment_file.name);
      host_environment_files = opts.hermes.environment_files ++ sops_environment_files;
      guest_environment_files = lib.imap0 (index: _host_path: "${guest_env_dir}/${toString index}") host_environment_files;
      env_mounts = lib.listToAttrs (lib.imap0 (index: host_path: {
          name = "${guest_env_dir}/${toString index}";
          value = {
            hostPath = host_path;
            isReadOnly = true;
          };
        })
        host_environment_files);
    in {
      assertions = [
        {
          assertion = !(lib.hasInfix "_" container_name);
          message = "my.unit.hermes-agent.container.name must not contain underscores; NixOS containers reject underscores.";
        }
        {
          assertion = !opts.nat.enable || opts.nat.external_interface != null;
          message = "my.unit.hermes-agent.nat.external_interface must be set when NAT is enabled.";
        }
      ];

      sops.secrets = optionalAttrs sops_environment_file.enable {
        ${sops_environment_file.name} = s.mk_secret sops_environment_file.file sops_environment_file.key {};
      };

      systemd.tmpfiles.rules = [
        "d ${opts.state_dir} 0750 root root - -"
      ];

      my."unit.hermes-agent".backup.items.state = {
        kind = "path";
        policy = "sensitive_data";
        path.paths = [opts.state_dir];
      };

      networking.nat = optionalAttrs opts.nat.enable ({
          enable = true;
          internalInterfaces = lib.mkAfter [container_veth];
        }
        // optionalAttrs (opts.nat.external_interface != null) {
          externalInterface = lib.mkDefault opts.nat.external_interface;
        });

      my.vhosts =
        optionalAttrs dashboard.enable {
          hermes-dashboard = {
            inherit (dashboard) target;
            sources = ["http://${local_address}:${toString dashboard.port}"];
          };
        }
        // optionalAttrs api.enable {
          hermes-api = {
            inherit (api) target;
            sources = ["http://${local_address}:${toString api.port}"];
          };
        };

      containers.${container_name} = {
        autoStart = opts.container.auto_start;
        privateNetwork = true;
        privateUsers = opts.container.private_users;
        restartIfChanged = true;

        hostAddress = host_address;
        localAddress = local_address;

        bindMounts =
          {
            "${guest_state_dir}" = {
              hostPath = opts.state_dir;
              isReadOnly = false;
            };
          }
          // env_mounts;
        config = {
          lib,
          pkgs,
          ...
        }: {
          system.stateVersion = "25.11";

          environment.systemPackages =
            [
              opts.package
              pkgs.git
              pkgs.ripgrep
            ]
            ++ opts.hermes.extra_packages;

          networking = {
            useHostResolvConf = lib.mkForce false;
            firewall.enable = true;
            firewall.allowedTCPPorts =
              lib.optionals dashboard.enable [dashboard.port]
              ++ lib.optionals api.enable [api.port];
          };
          services.resolved.enable = true;

          users.groups.hermes = {};
          users.users.hermes = {
            isSystemUser = true;
            group = "hermes";
            home = guest_home_dir;
            shell = pkgs.bashInteractive;
          };

          system.activationScripts.hermes_agent_setup = lib.stringAfter ["users"] ''
            install -d -o hermes -g hermes -m 0750 ${guest_state_dir}
            install -d -o hermes -g hermes -m 0750 ${guest_hermes_home}
            install -d -o hermes -g hermes -m 0750 ${guest_home_dir}
            install -d -o hermes -g hermes -m 2770 ${guest_workspace}
            install -o hermes -g hermes -m 0640 ${config_yaml} ${guest_hermes_home}/config.yaml
            rm -f ${guest_hermes_home}/.managed
            ${lib.optionalString sops_environment_file.enable "install -o hermes -g hermes -m 0640 ${builtins.head guest_environment_files} ${guest_hermes_home}/.env"}
          '';

          systemd = {
            tmpfiles.rules = [
              "d ${guest_state_dir} 0750 hermes hermes - -"
              "d ${guest_hermes_home} 0750 hermes hermes - -"
              "d ${guest_home_dir} 0750 hermes hermes - -"
              "d ${guest_workspace} 2770 hermes hermes - -"
              "d ${guest_env_dir} 0750 root root - -"
            ];

            services.hermes-agent = {
              description = "Hermes Agent Gateway";
              wantedBy = ["multi-user.target"];
              after = ["network-online.target"];
              wants = ["network-online.target"];
              path =
                [
                  opts.package
                  pkgs.bash
                  pkgs.coreutils
                  pkgs.git
                  pkgs.curl
                  pkgs.ripgrep
                  pkgs.fd
                  pkgs.jq
                ]
                ++ opts.hermes.extra_packages;
              environment =
                {
                  HOME = guest_home_dir;
                  HERMES_HOME = guest_hermes_home;
                  MESSAGING_CWD = guest_workspace;
                }
                // optionalAttrs api.enable {
                  API_SERVER_ENABLED = "true";
                  API_SERVER_HOST = "0.0.0.0";
                  API_SERVER_PORT = toString api.port;
                  API_SERVER_CORS_ORIGINS = lib.concatStringsSep "," api_cors_origins;
                };
              serviceConfig =
                {
                  User = "hermes";
                  Group = "hermes";
                  WorkingDirectory = guest_workspace;
                  ExecStart = pkgs.writeShellScript "hermes-agent-start" ''
                    exec ${lib.escapeShellArgs (["${opts.package}/bin/hermes" "gateway" "run"] ++ opts.hermes.extra_args)}
                  '';
                  Restart = "always";
                  RestartSec = "10s";
                  UMask = "0007";
                  NoNewPrivileges = true;
                  PrivateTmp = true;
                }
                // optionalAttrs (guest_environment_files != []) {
                  EnvironmentFile = guest_environment_files;
                };
            };

            services.hermes-dashboard = o.when dashboard.enable {
              description = "Hermes Agent Web Dashboard";
              wantedBy = ["multi-user.target"];
              after = ["network-online.target" "hermes-agent.service"];
              wants = ["network-online.target" "hermes-agent.service"];
              path = [
                opts.package
                pkgs.bash
                pkgs.coreutils
                pkgs.git
                pkgs.nodejs
              ];
              environment =
                {
                  HOME = guest_home_dir;
                  HERMES_HOME = guest_hermes_home;
                  MESSAGING_CWD = guest_workspace;
                  HERMES_WEB_DIST = dashboard_web_dist;
                }
                // optionalAttrs dashboard.tui {
                  HERMES_DASHBOARD_TUI = "1";
                };
              serviceConfig =
                {
                  User = "hermes";
                  Group = "hermes";
                  WorkingDirectory = guest_workspace;
                  ExecStart = pkgs.writeShellScript "hermes-dashboard-start" ''
                    exec ${lib.escapeShellArgs ([
                        "${opts.package}/bin/hermes"
                        "dashboard"
                        "--host"
                        "0.0.0.0"
                        "--port"
                        (toString dashboard.port)
                        "--no-open"
                        "--insecure"
                      ]
                      ++ lib.optional dashboard.tui "--tui")}
                  '';
                  Restart = "always";
                  RestartSec = "10s";
                  UMask = "0007";
                  NoNewPrivileges = true;
                  PrivateTmp = true;
                }
                // optionalAttrs (guest_environment_files != []) {
                  EnvironmentFile = guest_environment_files;
                };
            };
          };
        };
      };
    }))
