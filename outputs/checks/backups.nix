{
  self,
  lib,
  pkgs,
  ...
}: let
  tyrant = self.nixosConfigurations.tyrant.config;
  lavpc = self.nixosConfigurations.lavpc.config;
  backup_lib = import ../../_lib/units/_backup {
    inherit (pkgs) lib;
    config = tyrant;
    inherit pkgs;
  };
  collect = import ../../users/_units/backup/_collect.nix;
  render_local = import ../../users/_units/backup/_render_local.nix;
  unit_defaults = import ../../globals/units.nix {inherit (pkgs) lib;};
  synthetic_item_secrets = backup_lib.render_item_secrets synthetic_items;
  synthetic_destination_secrets = backup_lib.render_destination_secrets tyrant.my."unit.backup".destinations;
  synthetic_items = [
    {
      source_host = "tyrant";
      unit_name = "db";
      item_name = "postgres";
      item = {
        enable = true;
        kind = "postgres_dump";
        policy = "critical_infra";
        tags = [];
        run_as_user = "postgres";
        prepare = null;
        cleanup = null;
        schedule = null;
        retention = null;
        promote_to = null;
        path = null;
        btrfs_snapshot = null;
        postgres_dump = {
          database = "app";
        };
        mysql_dump = null;
        custom = null;
      };
    }
    {
      source_host = "tyrant";
      unit_name = "db";
      item_name = "mysql";
      item = {
        enable = true;
        kind = "mysql_dump";
        policy = "critical_infra";
        tags = [];
        run_as_user = "mysql";
        prepare = null;
        cleanup = null;
        schedule = null;
        retention = null;
        promote_to = null;
        path = null;
        btrfs_snapshot = null;
        postgres_dump = null;
        mysql_dump = {
          database = "app";
          host = "127.0.0.1";
          port = 3306;
          username = "backup";
          password_secret = {
            name = "mysql_password";
            file = "backups.yaml";
            key = "mysql_password";
          };
        };
        custom = null;
      };
    }
    {
      source_host = "tyrant";
      unit_name = "service";
      item_name = "custom";
      item = {
        enable = true;
        kind = "custom";
        policy = "sensitive_data";
        tags = [];
        run_as_user = "root";
        prepare = null;
        cleanup = null;
        schedule = null;
        retention = null;
        promote_to = null;
        path = null;
        btrfs_snapshot = null;
        postgres_dump = null;
        mysql_dump = null;
        custom = {
          command = "printf custom-data";
          stdin_filename = "custom.dump";
        };
      };
    }
  ];
  synthetic_resolved = backup_lib.resolve_items {
    host_name = "tyrant";
    inherit (tyrant.my."unit.backup") destinations;
    inherit (tyrant.my."unit.backup") policies;
    items = synthetic_items;
  };
  synthetic_rendered = render_local {
    inherit lib pkgs;
    resolved_items = synthetic_resolved;
  };
  synthetic_collected = collect {
    u = {backup = backup_lib;};
    host_name = "tyrant";
    inherit (tyrant.my."unit.backup") destinations;
    inherit (tyrant.my."unit.backup") policies;
    host_items = {
      root = {
        enable = true;
        kind = "path";
        policy = "filesystem_snapshot";
        tags = [];
        run_as_user = "root";
        prepare = null;
        cleanup = null;
        schedule = null;
        retention = null;
        promote_to = null;
        path = {
          paths = ["/"];
          exclude = [];
        };
        btrfs_snapshot = null;
        postgres_dump = null;
        mysql_dump = null;
        custom = null;
      };
    };
    unit_items = {
      db = {
        postgres = {
          enable = true;
          kind = "postgres_dump";
          policy = "critical_infra";
          tags = [];
          run_as_user = "postgres";
          prepare = null;
          cleanup = null;
          schedule = null;
          retention = null;
          promote_to = null;
          path = null;
          btrfs_snapshot = null;
          postgres_dump = {
            database = "app";
          };
          mysql_dump = null;
          custom = null;
        };
      };
    };
  };
  invalid_unit_owned_item_eval =
    builtins.tryEval
    (self.nixosConfigurations.tyrant.extendModules {
      modules = [
        {
          my."unit.qbittorrent".backup.items.invalid = {
            enable = true;
          };
        }
      ];
    }).config.my."unit.qbittorrent".backup.items.invalid.kind;
  fxsync_mariadb_secret_owner_eval = builtins.tryEval tyrant.sops.secrets.fxsync_mariadb_password.owner;
  postgres_item = builtins.elemAt synthetic_resolved.local_to_a 0;
  mysql_item = builtins.elemAt synthetic_resolved.local_to_a 1;
  custom_item = builtins.elemAt synthetic_resolved.local_to_a 2;
  postgres_service = synthetic_rendered.${postgres_item.local_job_name};
  collected_unit_item = builtins.elemAt synthetic_collected.unit_owned_items 0;
in {
  backups_eval = assert tyrant.my."unit.backup".enable;
  assert tyrant.my."unit.backup".coordinator_host == "tyrant";
  assert lavpc.my."unit.backup".coordinator_host == "tyrant";
  assert tyrant.my."unit.backup".policies ? filesystem_snapshot;
  assert tyrant.my."unit.backup".policies.critical_infra.promote_to == ["B" "C"];
  assert tyrant.my."unit.backup".policies.critical_infra.timerConfig.OnCalendar == "*:0/6";
  assert tyrant.my."unit.backup".policies.critical_infra.forget == ["--keep-daily 14" "--keep-weekly 8" "--group-by host"];
  assert tyrant.my."unit.backup".policies.sensitive_data.promote_to == ["B" "C"];
  assert tyrant.my."unit.backup".policies.sensitive_data.timerConfig.OnCalendar == "*-*-* 00/12:00:00";
  assert !(unit_defaults.my."unit.backup" ? coordinator_host);
  assert builtins.isList postgres_item.command;
  assert builtins.length postgres_item.command == 1;
  assert postgres_item.stdin_filename == "tyrant_db_postgres_postgres-dump.sql";
  assert builtins.isList mysql_item.command;
  assert builtins.length mysql_item.command == 1;
  assert mysql_item.stdin_filename == "tyrant_db_mysql_mysql-dump.sql";
  assert postgres_item.service_user == "root";
  assert postgres_item.payload_user == "postgres";
  assert mysql_item.service_user == "mysql";
  assert mysql_item.payload_user == null;
  assert postgres_service.user == "root";
  assert builtins.length postgres_service.command == 5;
  assert builtins.elemAt postgres_service.command 0 == "${pkgs.util-linux}/bin/runuser";
  assert builtins.elemAt postgres_service.command 1 == "-u";
  assert builtins.elemAt postgres_service.command 2 == "postgres";
  assert builtins.elemAt postgres_service.command 3 == "--";
  assert builtins.elemAt postgres_service.command 4 == builtins.toString (builtins.elemAt postgres_item.command 0);
  assert synthetic_item_secrets ? mysql_password;
  assert !(synthetic_item_secrets ? backup_restic_password_A);
  assert synthetic_destination_secrets ? backup_restic_password_A;
  assert builtins.length synthetic_collected.host_owned_items == 1;
  assert builtins.length synthetic_collected.unit_owned_items == 1;
  assert builtins.length synthetic_collected.collected_items == 2;
  assert !invalid_unit_owned_item_eval.success;
  assert fxsync_mariadb_secret_owner_eval.success;
  assert fxsync_mariadb_secret_owner_eval.value == tyrant.my.nix.username;
  assert collected_unit_item.unit_name == "db";
  assert collected_unit_item.item_name == "postgres";
  assert custom_item.paths == [];
  assert builtins.isList custom_item.command;
  assert builtins.length custom_item.command == 1;
  assert custom_item.stdin_filename == "custom.dump";
  assert tyrant.services.restic.backups ? tyrant_root_snapshot_to_a;
  assert tyrant.services.restic.backups ? tyrant_home_snapshot_to_a;
  assert tyrant.services.restic.backups ? tyrant_pihole_state_to_a;
  assert tyrant.services.restic.backups ? tyrant_traefik_acme_to_a;
  assert tyrant.services.restic.backups ? tyrant_actual_budget_state_to_a;
  assert tyrant.services.restic.backups ? tyrant_fxsync_syncstorage_db_to_a;
  assert tyrant.services.restic.backups ? tyrant_fxsync_tokenserver_db_to_a;
  assert !(tyrant.services.restic.backups ? tyrant_qbittorrent_to_a);
  assert !(tyrant.services.restic.backups ? tyrant_nixarr_to_a);
  assert lib.elem "unit:fxsync" tyrant.services.restic.backups.tyrant_fxsync_syncstorage_db_to_a.extraBackupArgs;
  assert tyrant.services.restic.backups ? tyrant_shared_docs_core_to_a;
  assert tyrant.services.restic.backups.tyrant_shared_docs_core_to_a.paths == ["/srv/shared/docs/core"];
  assert tyrant.services.restic.backups.tyrant_root_snapshot_to_a.pruneOpts == [];
  assert tyrant.services.restic.backups.tyrant_root_snapshot_to_a.checkOpts == [];
  assert tyrant.services.restic.backups.tyrant_root_snapshot_to_a.user == "root";
  assert tyrant.services.restic.backups.tyrant_root_snapshot_to_a.backupPrepareCommand != null;
  assert tyrant.systemd.services ? backup_promote_tyrant_home_snapshot_to_b;
  assert tyrant.systemd.services ? backup_forget_tyrant_home_snapshot_on_a;
  assert tyrant.systemd.services ? backup_prune_tyrant_a;
  assert tyrant.systemd.services ? backup_prune_tyrant_b;
  assert tyrant.systemd.services ? backup_check_tyrant_a;
  assert tyrant.systemd.services ? backup_check_tyrant_b;
  assert !(tyrant.systemd.services ? backup_promote_tyrant_home_snapshot_to_c);
  assert tyrant.systemd.services.backup_promote_tyrant_home_snapshot_to_b.serviceConfig.Type == "oneshot";
  assert lib.hasInfix "init --from-repo" tyrant.my."unit.backup".rendered.services.backup_promote_tyrant_home_snapshot_to_b.script;
  assert lib.hasInfix "--copy-chunker-params" tyrant.my."unit.backup".rendered.services.backup_promote_tyrant_home_snapshot_to_b.script;
  assert tyrant.my."unit.backup".rendered.services.backup_promote_tyrant_home_snapshot_to_b.after == ["network-online.target"];
  assert tyrant.my."unit.backup".rendered.services.backup_promote_tyrant_home_snapshot_to_b.wants == ["network-online.target"];
  assert tyrant.my."unit.backup".rendered.services.backup_forget_tyrant_home_snapshot_on_b.after == ["network-online.target"];
  assert tyrant.my."unit.backup".rendered.services.backup_forget_tyrant_home_snapshot_on_b.wants == ["network-online.target"];
  assert tyrant.my."unit.backup".rendered.services.backup_prune_tyrant_b.after == ["network-online.target"];
  assert tyrant.my."unit.backup".rendered.services.backup_prune_tyrant_b.wants == ["network-online.target"];
  assert tyrant.my."unit.backup".rendered.services.backup_check_tyrant_b.after == ["network-online.target"];
  assert tyrant.my."unit.backup".rendered.services.backup_check_tyrant_b.wants == ["network-online.target"];
  assert lib.elem tyrant.programs.ssh.package tyrant.my."unit.backup".rendered.services.backup_promote_tyrant_home_snapshot_to_b.path;
  assert tyrant.my."unit.backup".rendered.services ? backup_promote_tyrant_shared_docs_core_to_b;
  assert tyrant.my."unit.backup".rendered.services ? backup_forget_tyrant_shared_docs_core_on_a;
  assert tyrant.my."unit.backup".rendered.services ? backup_forget_tyrant_shared_docs_core_on_b;
  assert lavpc.my."unit.backup".rendered.services == {};
    pkgs.runCommand "backups-eval" {} "touch $out";
}
