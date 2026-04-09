{
  config,
  lib,
  pkgs,
  mylib,
  ...
}: let
  inherit (lib) concatMapStringsSep mkDefault;

  my = mylib.use config;
  o = my.options;
in
  o.module "storage" (with o; {
    server = {
      enable = toggle "shared storage server" false;

      shared_root = opt "Canonical server-side root for shared NFS storage." t.str "/srv/shared";

      graveyard_root = opt "Root directory used by rip for retained deletions." t.str "/srv/graveyard";

      syncthing_src_root = opt "Canonical server-side storage path for the Syncthing src folder." t.str "/srv/syncthing/src";

      allowed_clients = opt "Explicitly whitelisted NFS client hostnames or addresses." (t.listOf t.str) ["lavpc"];

      downloads_retention = {
        max_age_days = opt "Delete downloads older than this many days." t.int 30;
        large_file_min_mb = opt "Large-file threshold in megabytes for earlier downloads cleanup." t.int 100;
        large_file_age_days = opt "Delete large downloads older than this many days." t.int 15;
        graveyard_retention_days = opt "Permanently purge graveyard contents older than this many days." t.int 30;
      };
    };
  }) {} (
    opts: let
      cfg = opts.server;
      retention = cfg.downloads_retention;

      shared_directories = [
        cfg.shared_root
        "${cfg.shared_root}/docs"
        "${cfg.shared_root}/docs/core"
        "${cfg.shared_root}/dwnl"
        "${cfg.shared_root}/vids"
        "${cfg.shared_root}/pics"
        "${cfg.shared_root}/misc"
      ];

      export_options = "(rw,sync,no_subtree_check,root_squash,fsid=0)";

      downloads_retention_script = pkgs.writeShellScript "storage-downloads-retention" ''
        set -euo pipefail

        downloads_dir="${cfg.shared_root}/dwnl"
        export RIP_GRAVEYARD="${cfg.graveyard_root}"

        [ -d "$downloads_dir" ] || exit 0
        ${pkgs.coreutils}/bin/mkdir -p "$RIP_GRAVEYARD"

        ${pkgs.findutils}/bin/find "$downloads_dir" -mindepth 1 -maxdepth 1 \
          \( -mtime +${toString (retention.max_age_days - 1)} -o \
             \( -type f -size +${toString retention.large_file_min_mb}M -mtime +${toString (retention.large_file_age_days - 1)} \) \
          \) -print0 \
        | ${pkgs.findutils}/bin/xargs -0 -r -- ${pkgs.rm-improved}/bin/rip --graveyard "$RIP_GRAVEYARD"
      '';

      graveyard_prune_script = ../../../_scripts/storage/storage-graveyard-prune.py;
    in
      o.when cfg.enable {
        my."unit.syncthing".src_root = mkDefault cfg.syncthing_src_root;

        services.nfs.server = {
          enable = true;
          exports = concatMapStringsSep "\n" (client: "${cfg.shared_root} ${client}${export_options}") cfg.allowed_clients;
        };

        networking.firewall.allowedTCPPorts = [111 2049];
        networking.firewall.allowedUDPPorts = [111 2049];

        systemd = {
          tmpfiles.rules =
            map (path: "d ${path} 2770 root users - -") shared_directories
            ++ [
              "d ${cfg.graveyard_root} 0700 root root - -"
            ];

          services = {
            storage-downloads-retention = {
              description = "Move expired shared downloads into the graveyard";
              serviceConfig = {
                Type = "oneshot";
                ExecStart = downloads_retention_script;
              };
            };

            storage-graveyard-prune = {
              description = "Permanently purge expired graveyard entries";
              requires = ["storage-downloads-retention.service"];
              after = ["storage-downloads-retention.service"];
              serviceConfig = {
                Type = "oneshot";
                ExecStart = "${pkgs.python3}/bin/python3 ${graveyard_prune_script} --graveyard-root ${cfg.graveyard_root} --retention-days ${toString retention.graveyard_retention_days}";
              };
            };
          };

          timers = {
            storage-downloads-retention = {
              wantedBy = ["timers.target"];
              timerConfig = {
                OnCalendar = "daily";
                Persistent = true;
              };
            };

            storage-graveyard-prune = {
              wantedBy = ["timers.target"];
              timerConfig = {
                OnCalendar = "daily";
                Persistent = true;
              };
            };
          };
        };
      }
  )
