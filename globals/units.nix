# Non-host specific settings go here for defining units
# They should not be enabled here, otherwise they'd be enabled for every host.
# These reference units declared at `../users/_units`
{lib, ...}: {
  my = {
    "unit.octodns" = {
    };

    "unit.pihole" = {
    };

    "unit.nixarr" = {
    };

    "unit.fxsync" = {
    };

    "unit.fail2ban" = {
      enable = true;
    };

    "unit.backup" = {
      enable = lib.mkDefault false;
      state_dir = lib.mkDefault "/var/lib/backups";
      destinations = {
        A = {
          enable = lib.mkDefault false;
          backend = lib.mkDefault "filesystem";
          repository_template = lib.mkDefault "/var/lib/backups/repos/{host}";
          password_secret = lib.mkDefault {
            name = "backup_restic_password_A";
            file = "backups.yaml";
            key = "restic_a_password";
          };
          extra_options = lib.mkDefault [];
        };
        B = {
          enable = lib.mkDefault false;
          backend = lib.mkDefault "sftp";
          repository_template = lib.mkDefault "sftp:backup@example:/var/lib/backups/repos/{host}";
          password_secret = lib.mkDefault {
            name = "backup_restic_password_B";
            file = "backups.yaml";
            key = "restic_b_password";
          };
          environment_secret = lib.mkDefault {
            name = "backup_restic_env_B";
            file = "backups.yaml";
            key = "restic_b_env";
          };
          extra_options = lib.mkDefault [];
        };
        C = {
          enable = lib.mkDefault false;
          backend = lib.mkDefault "rclone";
          repository_template = lib.mkDefault "rclone:external:{host}";
          password_secret = lib.mkDefault {
            name = "backup_restic_password_C";
            file = "backups.yaml";
            key = "restic_c_password";
          };
          environment_secret = lib.mkDefault {
            name = "backup_restic_env_C";
            file = "backups.yaml";
            key = "restic_c_env";
          };
          extra_options = lib.mkDefault [];
        };
      };
      policies = {
        filesystem_snapshot = {
          timerConfig = {
            OnCalendar = "daily";
            Persistent = "true";
          };
          promotion_timerConfig = {
            OnCalendar = "daily";
            RandomizedDelaySec = "30m";
            Persistent = "true";
          };
          forget_timerConfig = {
            OnCalendar = "daily";
            Persistent = "true";
          };
          prune_timerConfig = {
            OnCalendar = "weekly";
            Persistent = "true";
          };
          check_timerConfig = {
            OnCalendar = "weekly";
            Persistent = "true";
          };
          promote_to = [];
          forget = ["--keep-daily 3" "--group-by host"];
          check = ["--read-data-subset=5%"];
        };
        critical_infra = {
          timerConfig = {
            OnCalendar = "*:0/6";
            Persistent = "true";
          };
          promotion_timerConfig = {
            OnCalendar = "*:0/6";
            RandomizedDelaySec = "15m";
            Persistent = "true";
          };
          forget_timerConfig = {
            OnCalendar = "daily";
            Persistent = "true";
          };
          prune_timerConfig = {
            OnCalendar = "weekly";
            Persistent = "true";
          };
          check_timerConfig = {
            OnCalendar = "weekly";
            Persistent = "true";
          };
          promote_to = ["B" "C"];
          forget = ["--keep-daily 14" "--keep-weekly 8" "--group-by host"];
          check = ["--read-data-subset=10%"];
        };
        sensitive_data = {
          timerConfig = {
            OnCalendar = "*-*-* 00/12:00:00";
            Persistent = "true";
          };
          promotion_timerConfig = {
            OnCalendar = "*-*-* 00/12:00:00";
            RandomizedDelaySec = "15m";
            Persistent = "true";
          };
          forget_timerConfig = {
            OnCalendar = "daily";
            Persistent = "true";
          };
          prune_timerConfig = {
            OnCalendar = "weekly";
            Persistent = "true";
          };
          check_timerConfig = {
            OnCalendar = "weekly";
            Persistent = "true";
          };
          promote_to = ["B" "C"];
          forget = ["--keep-daily 21" "--keep-weekly 12" "--group-by host"];
          check = ["--read-data-subset=10%"];
        };
      };
      host_items = {};
    };
  };
}
