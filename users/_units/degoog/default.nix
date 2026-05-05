{
  mylib,
  config,
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
  t = lib.types;
in
  o.module "unit.degoog" (with o; {
    enable = toggle "Enable Degoog search aggregator" false;
    package = mkOption {
      description = "Degoog package to run";
      type = lib.types.package;
      default = local_packages.degoog;
    };
    endpoint = u.endpoint {
      port = 4444;
      target = "search";
    };
    default_search_language = opt "Default Degoog search language" t.str "en-US";
  }) {} (opts:
    o.when opts.enable (let
      user = "degoog";
      group = "degoog";
      pkg = opts.package;
      state_dir = "/var/lib/degoog";
      runtime_dir = "/run/degoog";
      secret_file = s.secret_path "degoog_settings_passwords";
      env_file = "${runtime_dir}/env";
      plugin_settings_file = "${state_dir}/plugin-settings.json";

      prepare_env = pkgs.writeShellScript "degoog-prepare-env" ''
        set -euo pipefail

        mkdir -p "${runtime_dir}" "${state_dir}"
        chown ${user}:${group} "${runtime_dir}" "${state_dir}"
        chmod 0750 "${runtime_dir}" "${state_dir}"

        secret="$(cat "${secret_file}")"
        if [ -z "$secret" ]; then
          echo "Degoog settings passwords secret is empty" >&2
          exit 1
        fi

        env_tmp="$(mktemp "${runtime_dir}/env.XXXXXX")"
        printf 'DEGOOG_SETTINGS_PASSWORDS=%s\n' "$secret" > "$env_tmp"
        install -m 0640 -o root -g ${group} "$env_tmp" "${env_file}"
        rm -f "$env_tmp"

        if [ ! -e "${plugin_settings_file}" ]; then
          settings_tmp="$(mktemp "${state_dir}/plugin-settings.XXXXXX")"
          printf '%s\n' \
            '{' \
            '  "degoog-settings": {' \
            '    "domainBlockEnabled": "true",' \
            '    "domainBlockUiEnabled": "true"' \
            '  }' \
            '}' > "$settings_tmp"
          install -m 0640 -o ${user} -g ${group} "$settings_tmp" "${plugin_settings_file}"
          rm -f "$settings_tmp"
        fi
      '';
    in {
      my = {
        vhosts.degoog = {
          inherit (opts.endpoint) target sources;
        };
        "unit.degoog".backup.items.state = {
          kind = "path";
          policy = "sensitive_data";
          path.paths = [state_dir];
        };
      };

      sops.secrets.degoog_settings_passwords = s.mk_secret "${s.dir}/degoog.yaml" "degoog_settings_passwords" {
        owner = user;
        inherit group;
      };

      users.users.${user} = {
        inherit group;
        home = state_dir;
        isSystemUser = true;
      };
      users.groups.${group} = {};

      systemd.services.degoog-prepare-env = {
        description = "Prepare Degoog environment";
        before = ["degoog.service"];
        requiredBy = ["degoog.service"];
        partOf = ["degoog.service"];
        path = with pkgs; [coreutils];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = prepare_env;
        };
      };

      systemd.services.degoog = {
        description = "Degoog search aggregator";
        wantedBy = ["multi-user.target"];
        after = ["network-online.target" "degoog-prepare-env.service"];
        wants = ["network-online.target"];
        requires = ["degoog-prepare-env.service"];
        path = with pkgs; [git curl cacert];
        environment = {
          HOME = state_dir;
          LOG_LEVEL = "info";
          DEGOOG_PORT = toString opts.endpoint.port;
          DEGOOG_DATA_DIR = state_dir;
          DEGOOG_DEFAULT_SEARCH_LANGUAGE = opts.default_search_language;
        };
        serviceConfig = {
          Type = "simple";
          User = user;
          Group = group;
          WorkingDirectory = "${pkg}/libexec/degoog";
          StateDirectory = "degoog";
          RuntimeDirectory = "degoog";
          StateDirectoryMode = "0750";
          RuntimeDirectoryMode = "0750";
          EnvironmentFile = "/run/degoog/env";
          ExecStart = "${pkg}/bin/degoog";
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };
    }))
