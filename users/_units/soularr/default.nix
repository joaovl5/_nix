{
  mylib,
  config,
  pkgs,
  inputs,
  system,
  ...
}: let
  my = mylib.use config;
  o = my.options;
  s = my.secrets;
  u = my.units;
  cfg = config.my;
  nix_cfg = config.my.nix;
  inherit (o) t;
in
  o.module "unit.soularr" (with o; {
    enable = toggle "Enable Soularr" false;
    slskd = {
      host_ip = opt "Host IP (used for DNS)" t.str "127.0.0.1";
      host = opt "Host domain (used for DNS)" t.str "sls.soul.lan";
      port = opt "Port for Slskd web UI" t.int 55090;
    };
    soularr = {
      interval = opt "Systemd timer calendar for Soularr runs" t.str "*:0/5";
    };
    migration = {
      interval = opt "Systemd timer calendar for migration" t.str "*:0/15";
    };
  }) {} (opts:
    o.when opts.enable (let
      inherit (config) nixarr;
      lidarr_port = cfg."unit.nixarr".lidarr.port;
      user = nix_cfg.username;
      group = "users";

      # Soularr package from flake input
      soularr_pkg = inputs.soularr.packages.${system}.default;

      # User-owned directories
      data_dir = "${u.data_dir}/soularr/data/music";
      state_dir = "${u.data_dir}/soularr/state";
      config_dir = "${u.data_dir}/soularr/config";
      downloads_dir = "${data_dir}/slskd_downloads";

      # Root-owned target directory
      target_music_dir = "${nixarr.mediaDir}/library/music";

      # Runtime path for generated config.ini
      soularr_cfg_path = "${config_dir}/config.ini";

      # Script to generate config.ini at runtime from secrets
      generate_config_script = pkgs.writeShellScript "soularr-generate-config" ''
        set -euo pipefail

        LIDARR_API_KEY=$(cat ${s.secret_path "soularr_lidarr_api_key"})
        SLSKD_API_KEY=$(cat ${s.secret_path "soularr_slskd_api_key"})

        mkdir -p "${config_dir}"

        cat > "${soularr_cfg_path}" << EOF
[Lidarr]
api_key = $LIDARR_API_KEY
host_url = http://127.0.0.1:${toString lidarr_port}
download_dir = ${downloads_dir}
disable_sync = False

[Slskd]
api_key = $SLSKD_API_KEY
host_url = http://127.0.0.1:${toString opts.slskd.port}
url_base = /
download_dir = ${downloads_dir}
delete_searches = False
stalled_timeout = 3600

[Release Settings]
use_most_common_tracknum = True
allow_multi_disc = True
accepted_countries = Europe,Japan,United Kingdom,United States,[Worldwide],Australia,Canada
skip_region_check = False
accepted_formats = CD,Digital Media,Vinyl

[Search Settings]
search_timeout = 5000
maximum_peer_queue = 50
minimum_peer_upload_speed = 0
minimum_filename_match_ratio = 0.8
allowed_filetypes = flac 24/192,flac 16/44.1,flac,mp3 320,mp3
ignored_users =
album_prepend_artist = False
track_prepend_artist = True
search_type = incrementing_page
number_of_albums_to_grab = 10
remove_wanted_on_failure = False
title_blacklist =
search_blacklist =
search_source = missing
enable_search_denylist = False
max_search_failures = 3

[Download Settings]
download_filtering = True
use_extension_whitelist = False
extensions_whitelist = lrc,nfo,txt

[Logging]
level = INFO
format = [%(levelname)s|%(module)s|L%(lineno)d] %(asctime)s: %(message)s
datefmt = %Y-%m-%dT%H:%M:%S%z
EOF

        chmod 644 "${soularr_cfg_path}"
      '';

      # Script to start native slskd with secrets
      start_slskd_script = pkgs.writeShellScript "slskd-start" ''
        set -euo pipefail

        SLSKD_USERNAME="$(cat ${s.secret_path "soularr_slskd_username"})"
        SLSKD_PASSWORD="$(cat ${s.secret_path "soularr_slskd_password"})"
        SLSKD_SOULSEEK_USERNAME="$(cat ${s.secret_path "soularr_slskd_soulseek_username"})"
        SLSKD_SOULSEEK_PASSWORD="$(cat ${s.secret_path "soularr_slskd_soulseek_password"})"
        SLSKD_API_KEY="$(cat ${s.secret_path "soularr_slskd_api_key"})"

        exec ${pkgs.slskd}/bin/slskd \
          --app-dir "${state_dir}/slskd" \
          --http-port ${toString opts.slskd.port} \
          --no-https \
          --slsk-listen-port 50300 \
          --username "$SLSKD_USERNAME" \
          --password "$SLSKD_PASSWORD" \
          --slsk-username "$SLSKD_SOULSEEK_USERNAME" \
          --slsk-password "$SLSKD_SOULSEEK_PASSWORD" \
          --api-key "$SLSKD_API_KEY" \
          --downloads "${downloads_dir}" \
          --shared "${data_dir}" \
          --remote-configuration
      '';

      # Script to run soularr
      run_soularr_script = pkgs.writeShellScript "soularr-run" ''
        set -euo pipefail
        cd "${config_dir}"
        exec ${soularr_pkg}/bin/soularr
      '';

      # Migration script that runs as root
      migrate_script = pkgs.writeShellScript "soularr-migrate" ''
        set -euo pipefail

        SOURCE_DIR="${downloads_dir}"
        TARGET_DIR="${target_music_dir}"

        # Check if source directory exists and has files
        if [ ! -d "$SOURCE_DIR" ]; then
          echo "Source directory does not exist: $SOURCE_DIR"
          exit 0
        fi

        # Check if there are any files to migrate
        if [ -z "$(ls -A "$SOURCE_DIR" 2>/dev/null)" ]; then
          echo "No files to migrate"
          exit 0
        fi

        echo "Migrating files from $SOURCE_DIR to $TARGET_DIR"

        # Ensure target directory exists
        mkdir -p "$TARGET_DIR"

        # Use rsync to copy with proper ownership, then remove source
        ${pkgs.rsync}/bin/rsync -av --chown=root:root --remove-source-files "$SOURCE_DIR/" "$TARGET_DIR/"

        # Clean up empty directories in source
        find "$SOURCE_DIR" -type d -empty -delete 2>/dev/null || true

        echo "Migration complete"
      '';
    in {
      # SOPS secrets
      sops.secrets = {
        "soularr_lidarr_api_key" = s.mk_secret_user "${s.dir}/soularr.yaml" "lidarr_api_key" {
          inherit group;
        };
        "soularr_slskd_api_key" = s.mk_secret_user "${s.dir}/soularr.yaml" "slskd_api_key" {
          inherit group;
        };
        "soularr_slskd_username" = s.mk_secret_user "${s.dir}/soularr.yaml" "slskd_username" {
          inherit group;
        };
        "soularr_slskd_password" = s.mk_secret_user "${s.dir}/soularr.yaml" "slskd_password" {
          inherit group;
        };
        "soularr_slskd_soulseek_username" = s.mk_secret_user "${s.dir}/soularr.yaml" "slskd_soulseek_username" {
          inherit group;
        };
        "soularr_slskd_soulseek_password" = s.mk_secret_user "${s.dir}/soularr.yaml" "slskd_soulseek_password" {
          inherit group;
        };
      };

      # Open Soulseek port
      networking.firewall.allowedTCPPorts = [50300];

      # Ensure directories exist with proper ownership
      systemd.tmpfiles.rules = [
        "d ${u.data_dir}/soularr 0755 ${user} ${group} -"
        "d ${u.data_dir}/soularr/data 0755 ${user} ${group} -"
        "d ${data_dir} 0755 ${user} ${group} -"
        "d ${downloads_dir} 0755 ${user} ${group} -"
        "d ${state_dir} 0755 ${user} ${group} -"
        "d ${state_dir}/slskd 0755 ${user} ${group} -"
        "d ${config_dir} 0755 ${user} ${group} -"
      ];

      # User service for native slskd (autostart at boot)
      systemd.user.services.slskd = {
        enable = true;
        description = "[slskd] - Soulseek daemon";
        serviceConfig = {
          Type = "simple";
          ExecStart = start_slskd_script;
          Restart = "on-failure";
          RestartSec = "5s";
        };
        wantedBy = ["default.target"];
      };

      # User service for soularr (oneshot, triggered by timer)
      systemd.user.services.soularr = {
        enable = true;
        description = "[soularr] - Soulseek downloader for Lidarr";
        serviceConfig = {
          Type = "oneshot";
          ExecStartPre = generate_config_script;
          ExecStart = run_soularr_script;
        };
        after = ["slskd.service"];
        requires = ["slskd.service"];
      };

      # User timer for soularr (autostart at boot)
      systemd.user.timers.soularr = {
        enable = true;
        description = "Timer for Soularr service";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = opts.soularr.interval;
          Persistent = true;
        };
      };

      # Migration service (runs as root to handle permission elevation)
      systemd.services.soularr-migrate = {
        description = "Migrate Soularr downloads to Lidarr media directory";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = migrate_script;
        };
      };

      # Migration timer (autostart at boot)
      systemd.timers.soularr-migrate = {
        description = "Timer for Soularr migration service";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = opts.migration.interval;
          Persistent = true;
        };
      };
    }))
