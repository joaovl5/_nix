{
  mylib,
  config,
  inputs,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) concatLists concatStringsSep mkIf mkMerge mkOption types;
  local_packages = import ../../../packages {inherit pkgs inputs;};

  my = mylib.use config;
  o = my.options;
  s = my.secrets;
  u = my.units;
  inherit (o) t;

  user = "gopeed";
  group = "gopeed";
  media_group = "media";
  app_names = ["radarr" "sonarr" "lidarr"];
  app_titles = {
    radarr = "Radarr";
    sonarr = "Sonarr";
    lidarr = "Lidarr";
  };

  mk_app_dirs = root: app: {
    incoming = "${root}/${app}/incoming";
    work = "${root}/${app}/work";
    completed = "${root}/${app}/completed";
    submitted = "${root}/${app}/submitted";
    failed = "${root}/${app}/failed";
  };

  mk_app_options = app: default_enabled: {
    enable = o.toggle "Enable ${app_titles.${app}} Gopeed blackhole adapter" default_enabled;
  };
in
  o.module "unit.gopeed" (with o; {
    enable = toggle "Enable Gopeed Web" false;
    package = mkOption {
      description = "Gopeed Web package to run";
      type = types.package;
      default = local_packages.gopeed-web;
    };
    endpoint = u.endpoint {
      port = 12011;
      target = "torrent";
    };
    state_dir = opt "Gopeed state directory" t.str "/var/lib/gopeed";
    storage_dir = opt "Gopeed metadata storage directory" t.str "/var/lib/gopeed/storage";
    download_dir = opt "Default ad-hoc Gopeed download directory" t.str "/var/lib/gopeed/downloads";
    qbittorrent_archive_dir = opt "Directory for preserved qBittorrent payloads" t.str "/srv/torrents/qbittorrent-archive";
    max_running = opt "Maximum concurrent Gopeed download tasks" t.int 5;
    auth.username = opt "Gopeed Web username" t.str "gopeed";
    torrent = {
      peer_port = opt "BitTorrent peer listen port" t.int 55055;
      open_firewall = toggle "Open the BitTorrent peer port in the firewall" false;
    };
    blackhole = {
      enable = toggle "Enable Gopeed blackhole adapter for -arr services" true;
      root = opt "Gopeed blackhole root directory" t.str "/var/lib/gopeed/blackhole";
      radarr = mk_app_options "radarr" true;
      sonarr = mk_app_options "sonarr" true;
      lidarr = mk_app_options "lidarr" false;
    };
  }) {} (opts:
    o.when opts.enable (let
      blackhole_enabled = opts.blackhole.enable;
      enabled_apps = builtins.filter (app: opts.blackhole.${app}.enable) app_names;
      enabled_blackhole_apps =
        if blackhole_enabled
        then enabled_apps
        else [];
      app_dirs = builtins.listToAttrs (map (app: {
          name = app;
          value = mk_app_dirs opts.blackhole.root app;
        })
        app_names);
      enabled_app_dirs = map (app: app_dirs.${app}) enabled_blackhole_apps;
      white_download_dirs =
        [opts.download_dir]
        ++ map (dirs: "${dirs.work}/*") enabled_app_dirs;

      gopeed_secret_file = "${s.dir}/gopeed.yaml";
      complete_blackhole = pkgs.writeShellScript "gopeed-complete-blackhole" ''
        set -euo pipefail

        if [ "''${GOPEED_EVENT:-}" != "DOWNLOAD_DONE" ]; then
          exit 0
        fi

        task_path="''${GOPEED_TASK_PATH:-}"
        if [ -z "$task_path" ]; then
          exit 0
        fi

        move_completed_root() {
          app="$1"
          work_dir="$2"
          completed_dir="$3"

          case "$task_path" in
            "$work_dir"/*)
              relative_path="''${task_path#"$work_dir"/}"
              task_root_name="''${relative_path%%/*}"
              task_root="$work_dir/$task_root_name"
              dest="$completed_dir/$task_root_name"
              if [ ! -e "$task_root" ]; then
                exit 0
              fi
              if [ -e "$dest" ]; then
                dest="$dest-$(${pkgs.coreutils}/bin/date +%s)"
              fi
              ${pkgs.coreutils}/bin/mv -- "$task_root" "$dest"
              exit 0
              ;;
          esac
        }

        ${concatStringsSep "\n" (map (app: let
            dirs = app_dirs.${app};
          in ''
            move_completed_root ${app} ${dirs.work} ${dirs.completed}
          '')
          enabled_blackhole_apps)}
      '';
      gopeed_config = pkgs.writeText "gopeed-config.json" (builtins.toJSON {
        address = "127.0.0.1";
        port = opts.endpoint.port;
        username = opts.auth.username;
        storageDir = opts.storage_dir;
        whiteDownloadDirs = white_download_dirs;
        downloadConfig = {
          downloadDir = opts.download_dir;
          maxRunning = opts.max_running;
          protocolConfig.bt = {
            listenPort = opts.torrent.peer_port;
            seedKeep = false;
            seedRatio = 1.0;
            seedTime = 86400;
          };
          script = {
            enable = blackhole_enabled;
            paths = lib.optionals blackhole_enabled [complete_blackhole];
          };
        };
      });
      runtime_config = "/run/gopeed/config.json";
      prepare_gopeed_config = pkgs.writeShellScript "prepare-gopeed-config" ''
        set -euo pipefail
        umask 077

        ${pkgs.python3}/bin/python3 - \
          ${gopeed_config} \
          ${runtime_config} \
          ${s.secret_path "gopeed_web_password"} \
          ${s.secret_path "gopeed_api_token"} <<'PY'
        import json
        import pathlib
        import sys

        base_config, runtime_config, password_file, token_file = map(pathlib.Path, sys.argv[1:5])
        config = json.loads(base_config.read_text())
        config["password"] = password_file.read_text().strip()
        config["apiToken"] = token_file.read_text().strip()
        pathlib.Path(runtime_config).write_text(json.dumps(config))
        PY
      '';
      start_gopeed = pkgs.writeShellScript "start-gopeed" ''
        set -euo pipefail

        exec ${opts.package}/bin/gopeed-web -c ${runtime_config}
      '';
      mk_submit_blackhole = app: let
        dirs = app_dirs.${app};
      in
        pkgs.writeShellScript "gopeed-submit-${app}-blackhole" ''
          set -euo pipefail
          shopt -s nullglob

          api_url="http://127.0.0.1:${toString opts.endpoint.port}/api/v1/tasks"
          api_token="$(${pkgs.coreutils}/bin/cat ${s.secret_path "gopeed_api_token"})"
          status=0

          wait_for_stable_file() {
            file="$1"
            previous_size=""
            for _ in $(${pkgs.coreutils}/bin/seq 1 10); do
              if [ ! -f "$file" ]; then
                return 1
              fi
              current_size="$(${pkgs.coreutils}/bin/stat -c %s -- "$file")"
              if [ "$current_size" = "$previous_size" ]; then
                return 0
              fi
              previous_size="$current_size"
              ${pkgs.coreutils}/bin/sleep 1
            done
            return 1
          }

          move_to_dir() {
            file="$1"
            dir="$2"
            base="$(${pkgs.coreutils}/bin/basename -- "$file")"
            target="$dir/$base"
            if [ -e "$target" ]; then
              if [[ "$base" == *.* ]]; then
                stem="''${base%.*}"
                extension=".''${base##*.}"
              else
                stem="$base"
                extension=""
              fi
              target="$dir/$stem-$(${pkgs.coreutils}/bin/date +%s)$extension"
            fi
            ${pkgs.coreutils}/bin/mv -- "$file" "$target"
            printf '%s\n' "$target"
          }

          request_url_for() {
            file="$1"
            case "$file" in
              *.magnet)
                magnet_url=""
                IFS= read -r magnet_url < "$file" || true
                case "$magnet_url" in
                  magnet:*)
                    printf '%s\n' "$magnet_url"
                    ;;
                  *)
                    return 1
                    ;;
                esac
                ;;
              *)
                printf '%s\n' "$file"
                ;;
            esac
          }

          wait_for_api() {
            for _ in $(${pkgs.coreutils}/bin/seq 1 30); do
              if ${pkgs.curl}/bin/curl --fail --silent --show-error \
                --header "X-Api-Token: $api_token" \
                "$api_url" >/dev/null; then
                return 0
              fi
              ${pkgs.coreutils}/bin/sleep 1
            done
            return 1
          }

          if ! wait_for_api; then
            exit 1
          fi

          for request_file in ${dirs.incoming}/*.torrent ${dirs.incoming}/*.magnet; do
            if ! wait_for_stable_file "$request_file"; then
              move_to_dir "$request_file" ${dirs.failed} >/dev/null
              status=1
              continue
            fi

            work_name="$(${pkgs.python3}/bin/python3 - "$request_file" "${app}" <<'PY'
          import hashlib
          import pathlib
          import re
          import sys

          request_file = pathlib.Path(sys.argv[1])
          app = sys.argv[2]
          safe_name = re.sub(r"[^A-Za-z0-9._-]+", "-", request_file.stem).strip("-")[:80] or app
          digest = hashlib.sha256(request_file.read_bytes()).hexdigest()[:12]
          print(f"{safe_name}-{digest}")
          PY
            )"
            work_dir="${dirs.work}/$work_name"
            ${pkgs.coreutils}/bin/mkdir -p -- "$work_dir"
            stable_request="$(move_to_dir "$request_file" ${dirs.submitted})"

            if ! request_url="$(request_url_for "$stable_request")"; then
              move_to_dir "$stable_request" ${dirs.failed} >/dev/null
              status=1
              continue
            fi

            payload="$(${pkgs.python3}/bin/python3 - "$request_url" "$work_dir" "${app}" <<'PY'
          import json
          import sys

          request_url, work_dir, app = sys.argv[1:4]
          print(json.dumps({
              "req": {
                  "url": request_url,
                  "labels": {
                      "source": f"{app}-blackhole",
                  },
              },
              "opts": {
                  "path": work_dir,
              },
          }))
          PY
            )"

            if ! response="$(${pkgs.curl}/bin/curl --fail --silent --show-error \
              --request POST \
              --header 'Content-Type: application/json' \
              --header "X-Api-Token: $api_token" \
              --data "$payload" \
              "$api_url")"; then
              move_to_dir "$stable_request" ${dirs.failed} >/dev/null
              status=1
              continue
            fi

            if ! ${pkgs.python3}/bin/python3 - "$response" <<'PY'; then
          import json
          import sys

          response = json.loads(sys.argv[1])
          if response.get("code") != 0:
              raise SystemExit(response.get("msg") or "Gopeed task creation failed")
          PY
              move_to_dir "$stable_request" ${dirs.failed} >/dev/null
              status=1
              continue
            fi

          done

          exit "$status"
        '';
      mk_blackhole_path_unit = app: {
        wantedBy = ["multi-user.target"];
        pathConfig = {
          DirectoryNotEmpty = app_dirs.${app}.incoming;
          PathChanged = app_dirs.${app}.incoming;
          Unit = "gopeed-blackhole-${app}.service";
        };
      };
      mk_blackhole_service = app: {
        description = "Submit ${app_titles.${app}} torrent blackhole files to Gopeed";
        after = ["gopeed.service"];
        requires = ["gopeed.service"];
        path = with pkgs; [
          bash
          coreutils
          curl
          python3
        ];
        serviceConfig = {
          Type = "oneshot";
          User = user;
          Group = media_group;
          UMask = "0002";
          ExecStart = mk_submit_blackhole app;
        };
      };
      mk_blackhole_client = app: let
        dirs = app_dirs.${app};
      in {
        name = "Gopeed ${app_titles.${app}} Blackhole";
        implementation = "TorrentBlackhole";
        enable = true;
        fields = {
          torrentFolder = dirs.incoming;
          watchFolder = dirs.completed;
          saveMagnetFiles = true;
          magnetFileExtension = ".magnet";
          readOnly = true;
        };
      };
      tmpfiles_blackhole_rules = concatLists (map (app: let
          dirs = app_dirs.${app};
        in [
          "d '${opts.blackhole.root}/${app}' 2775 ${user} ${media_group} - -"
          "d '${dirs.incoming}' 2775 ${user} ${media_group} - -"
          "d '${dirs.work}' 2775 ${user} ${media_group} - -"
          "d '${dirs.completed}' 2775 ${user} ${media_group} - -"
          "d '${dirs.submitted}' 2775 ${user} ${media_group} - -"
          "d '${dirs.failed}' 2775 ${user} ${media_group} - -"
        ])
        enabled_blackhole_apps);
    in
      mkMerge [
        {
          assertions = [
            {
              assertion = !blackhole_enabled || config.nixarr.enable;
              message = "unit.gopeed.blackhole.enable requires unit.nixarr.enable = true";
            }
          ];
          warnings = lib.optionals (blackhole_enabled && opts.blackhole.lidarr.enable) [
            "unit.gopeed.blackhole.lidarr.enable only creates Gopeed directories/watchers; this nixarr revision has no Lidarr settings-sync, so configure Lidarr's Torrent Blackhole client manually."
          ];

          my.vhosts.gopeed = {
            inherit (opts.endpoint) target sources;
          };

          sops.secrets = {
            gopeed_web_password = s.mk_secret gopeed_secret_file "gopeed_web_password" {
              owner = user;
              inherit group;
            };
            gopeed_api_token = s.mk_secret gopeed_secret_file "gopeed_api_token" {
              owner = user;
              inherit group;
            };
          };

          users = {
            groups = {
              ${group} = {};
              ${media_group}.members = lib.optionals blackhole_enabled [user];
            };
            users.${user} = {
              inherit group;
              home = opts.state_dir;
              isSystemUser = true;
              extraGroups = lib.optionals blackhole_enabled [media_group];
            };
          };

          systemd.tmpfiles.rules =
            [
              "d '${opts.state_dir}' 0750 ${user} ${media_group} - -"
              "d '${opts.storage_dir}' 0750 ${user} ${media_group} - -"
              "d '${opts.download_dir}' 2775 ${user} ${media_group} - -"
              "d '${opts.blackhole.root}' 2775 ${user} ${media_group} - -"
              "d '/srv/torrents' 0755 root root - -"
              "d '${opts.qbittorrent_archive_dir}' 2775 ${user} ${media_group} - -"
            ]
            ++ tmpfiles_blackhole_rules;

          systemd.services.gopeed = {
            description = "Gopeed Web download service";
            wantedBy = ["multi-user.target"];
            after = ["network-online.target"];
            wants = ["network-online.target"];
            path = with pkgs; [
              bash
              coreutils
              curl
              python3
            ];
            environment = {
              HOME = opts.state_dir;
            };
            serviceConfig = {
              Type = "simple";
              User = user;
              Group = media_group;
              WorkingDirectory = opts.state_dir;
              StateDirectory = "gopeed";
              StateDirectoryMode = "0750";
              RuntimeDirectory = "gopeed";
              RuntimeDirectoryMode = "0750";
              UMask = "0002";
              Restart = "on-failure";
              RestartSec = "10s";
              ExecStartPre = [prepare_gopeed_config];
              ExecStart = start_gopeed;
            };
          };

          networking.firewall = mkIf opts.torrent.open_firewall {
            allowedTCPPorts = [opts.torrent.peer_port];
            allowedUDPPorts = [opts.torrent.peer_port];
          };
        }

        (mkIf blackhole_enabled {
          systemd.paths = builtins.listToAttrs (map (app: {
              name = "gopeed-blackhole-${app}";
              value = mk_blackhole_path_unit app;
            })
            enabled_blackhole_apps);
          systemd.services = builtins.listToAttrs (map (app: {
              name = "gopeed-blackhole-${app}";
              value = mk_blackhole_service app;
            })
            enabled_blackhole_apps);
        })

        (mkIf (blackhole_enabled && opts.blackhole.radarr.enable && config.nixarr.radarr.enable) {
          nixarr.radarr.settings-sync.downloadClients = [
            (mk_blackhole_client "radarr")
          ];
        })

        (mkIf (blackhole_enabled && opts.blackhole.sonarr.enable && config.nixarr.sonarr.enable) {
          nixarr.sonarr.settings-sync.downloadClients = [
            (mk_blackhole_client "sonarr")
          ];
        })
      ]))
