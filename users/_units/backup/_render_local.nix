{
  lib,
  pkgs,
  resolved_items,
}: let
  inherit (lib) concatLines escapeShellArg nameValuePair optionals;

  non_null = builtins.filter (value: value != null);

  join_script = commands:
    if commands == []
    then null
    else concatLines commands;

  normalize_command = command:
    if command == null
    then []
    else map builtins.toString command;

  btrfs_prepare_command = entry: let
    inherit (entry.payload) snapshot_path source_path;
  in ''
    set -eu
    ${pkgs.coreutils}/bin/mkdir -p ${escapeShellArg (builtins.dirOf snapshot_path)}
    if [ -e ${escapeShellArg snapshot_path} ]; then
      ${pkgs.btrfs-progs}/bin/btrfs subvolume delete ${escapeShellArg snapshot_path}
    fi
    ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r ${escapeShellArg source_path} ${escapeShellArg snapshot_path}
  '';

  btrfs_cleanup_command = entry: let
    inherit (entry.payload) snapshot_path;
  in ''
    set -eu
    if [ -e ${escapeShellArg snapshot_path} ]; then
      ${pkgs.btrfs-progs}/bin/btrfs subvolume delete ${escapeShellArg snapshot_path}
    fi
  '';

  mk_backup_prepare_command = entry:
    join_script (
      non_null [
        entry.prepare_command
        (
          if entry.kind == "btrfs_snapshot"
          then btrfs_prepare_command entry
          else null
        )
      ]
    );

  mk_backup_cleanup_command = entry:
    join_script (
      non_null [
        (
          if entry.kind == "btrfs_snapshot"
          then btrfs_cleanup_command entry
          else null
        )
        entry.cleanup_command
      ]
    );

  mk_local_job = entry: let
    destination = entry.destinations.A;
  in
    nameValuePair entry.local_job_name {
      inherit (destination) repository;
      passwordFile = destination.password_file;
      environmentFile = destination.environment_file;
      extraOptions = destination.extra_options;
      user = entry.run_as_user;
      inherit (entry) timerConfig;
      createWrapper = true;
      inherit (entry) paths;
      command = normalize_command entry.command;
      exclude =
        if entry.kind == "path"
        then entry.payload.exclude
        else [];
      extraBackupArgs =
        entry.tag_args
        ++ optionals (entry.stdin_filename != null) [
          "--stdin-filename"
          entry.stdin_filename
        ]
        ++ [
          "--group-by"
          "host,tags"
        ];
      backupPrepareCommand = mk_backup_prepare_command entry;
      backupCleanupCommand = mk_backup_cleanup_command entry;
      initialize = true;
    };
in
  builtins.listToAttrs (map mk_local_job resolved_items.local_to_a)
