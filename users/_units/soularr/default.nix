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
  cfg = config.my;
  inherit (o) t;
in
  o.module "unit.soularr" (with o; {
    enable = toggle "Enable Soularr" false;
    slskd = {
      host_ip = opt "Host IP (used for DNS)" t.str "127.0.0.1";
      host = opt "Host domain (used for DNS)" t.str "soulseek.lan";
      port = opt "Port for Slskd web UI" t.int 55090;
    };
    soularr = {
      interval = opt "Systemd timer calendar for Soularr runs" t.str "*:0/5";
    };
  }) {} (opts:
    o.when opts.enable (let
      inherit (config) nixarr;
      lidarr_port = cfg."unit.nixarr".lidarr.port;

      # Soularr package from flake input
      soularr_pkg = inputs.soularr.packages.${system}.default;

      # Directories - use nixarr.mediaDir directly (services run as root)
      music_dir = "${nixarr.mediaDir}/library/music";
      state_dir = "/var/lib/soularr";
      config_dir = "/var/lib/soularr/config";

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
        download_dir = ${music_dir}
        disable_sync = False

        [Slskd]
        api_key = $SLSKD_API_KEY
        host_url = http://127.0.0.1:${toString opts.slskd.port}
        url_base = /
        download_dir = ${music_dir}
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
          --downloads "${music_dir}" \
          --shared "${music_dir}" \
          --remote-configuration
      '';

      # Script to run soularr
      run_soularr_script = pkgs.writeShellScript "soularr-run" ''
        set -euo pipefail
        cd "${config_dir}"
        exec ${soularr_pkg}/bin/soularr
      '';
    in {
      # SOPS secrets (root-owned)
      sops.secrets = {
        "soularr_lidarr_api_key" = s.mk_secret "${s.dir}/soularr.yaml" "lidarr_api_key" {};
        "soularr_slskd_api_key" = s.mk_secret "${s.dir}/soularr.yaml" "slskd_api_key" {};
        "soularr_slskd_username" = s.mk_secret "${s.dir}/soularr.yaml" "slskd_username" {};
        "soularr_slskd_password" = s.mk_secret "${s.dir}/soularr.yaml" "slskd_password" {};
        "soularr_slskd_soulseek_username" = s.mk_secret "${s.dir}/soularr.yaml" "slskd_soulseek_username" {};
        "soularr_slskd_soulseek_password" = s.mk_secret "${s.dir}/soularr.yaml" "slskd_soulseek_password" {};
      };

      # Open Soulseek port
      networking.firewall.allowedTCPPorts = [50300];

      systemd = {
        # Ensure directories exist
        tmpfiles.rules = [
          "d ${state_dir} 0755 root root -"
          "d ${state_dir}/slskd 0755 root root -"
          "d ${config_dir} 0755 root root -"
        ];

        services = {
          # System service for slskd
          slskd = {
            enable = true;
            description = "[slskd] - Soulseek daemon";
            serviceConfig = {
              Type = "simple";
              ExecStart = start_slskd_script;
              Restart = "on-failure";
              RestartSec = "5s";
            };
            wantedBy = ["multi-user.target"];
          };

          # System service for soularr (oneshot, triggered by timer)
          soularr = {
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
        };

        # System timer for soularr
        timers.soularr = {
          enable = true;
          description = "Timer for Soularr service";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = opts.soularr.interval;
            Persistent = true;
          };
        };
      };
    }))
