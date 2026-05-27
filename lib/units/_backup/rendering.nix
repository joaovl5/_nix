_: {
  collect = {
    u,
    host_name,
    destinations,
    policies,
    host_items,
    unit_items,
  }: let
    mk_items = unit_name: items:
      map (item_name: {
        source_host = host_name;
        inherit unit_name item_name;
        item = items.${item_name};
      }) (builtins.attrNames items);

    host_owned_items = mk_items "host" host_items;

    unit_owned_items = builtins.concatLists (map (
      unit_name: mk_items unit_name unit_items.${unit_name}
    ) (builtins.attrNames unit_items));

    collected_items = host_owned_items ++ unit_owned_items;
  in {
    inherit host_owned_items unit_owned_items;
    inherit collected_items;
    resolved_items = u.backup.resolve_items {
      inherit host_name destinations policies;
      items = collected_items;
    };
  };

  render_local = {
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
        user = entry.service_user;
        inherit (entry) timerConfig;
        createWrapper = true;
        inherit (entry) paths;
        command =
          (optionals (entry.payload_user != null) [
            "${pkgs.util-linux}/bin/runuser"
            "-u"
            entry.payload_user
            "--"
          ])
          ++ normalize_command entry.command;
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
    builtins.listToAttrs (map mk_local_job resolved_items.local_to_a);

  render_promotion = {
    lib,
    pkgs,
    config,
    resolved_items,
  }: let
    inherit (lib) any concatMap concatStringsSep escapeShellArg nameValuePair optional optionalAttrs optionalString removeSuffix splitString toLower;

    restic = "${pkgs.restic}/bin/restic";
    ssh_package = lib.attrByPath ["programs" "ssh" "package"] pkgs.openssh config;
    host_name = config.networking.hostName;
    is_coordinator = host_name == config.my."unit.backup".coordinator_host;

    render_argv = args:
      concatStringsSep " " (map escapeShellArg args);

    split_words = value:
      builtins.filter (word: word != "") (splitString " " value);

    role_suffix = toLower;

    flatten = builtins.concatLists;

    item_stem = entry:
      removeSuffix "_to_a" entry.local_job_name;

    item_identity_tags = entry: [
      "host:${entry.source_host}"
      "unit:${entry.unit_name}"
      "item:${entry.item_name}"
    ];

    promotion_tags = entry: role:
      item_identity_tags entry
      ++ ["promote:${role}"];

    repo_args = destination:
      ["--repo" destination.repository]
      ++ optional (destination.password_file != null) "--password-file"
      ++ optional (destination.password_file != null) destination.password_file
      ++ destination.extra_options;

    from_repo_args = destination:
      ["--from-repo" destination.repository]
      ++ optional (destination.password_file != null) "--from-password-file"
      ++ optional (destination.password_file != null) destination.password_file
      ++ destination.extra_options;

    needs_network = destinations:
      any (destination: destination.backend != "filesystem") destinations;

    needs_ssh = destinations:
      any (destination: destination.backend == "sftp") destinations;

    mk_service = {
      name,
      script,
      environment_file ? null,
      network_online ? false,
      ssh_runtime ? false,
    }:
      nameValuePair name {
        after = optional network_online "network-online.target";
        path = optional ssh_runtime ssh_package;
        serviceConfig =
          {
            Type = "oneshot";
            User = "root";
          }
          // optionalAttrs (environment_file != null) {
            EnvironmentFile = environment_file;
          };
        wants = optional network_online "network-online.target";
        inherit script;
      };

    mk_timer = {
      name,
      timerConfig,
    }:
      nameValuePair name {
        wantedBy = ["timers.target"];
        timerConfig = timerConfig // {Unit = "${name}.service";};
      };

    mk_promotion_units = entry: let
      from = entry.destinations.A;
      base_name = item_stem entry;
    in
      map (role: let
        destination = entry.destinations.${role};
        role_name = role_suffix role;
        service_name = "backup_promote_${base_name}_to_${role_name}";
        destination_args = repo_args destination;
        source_args = from_repo_args from;
        init_args =
          destination_args
          ++ ["init"]
          ++ source_args
          ++ ["--copy-chunker-params"];
        probe_args = destination_args ++ ["cat" "config"];
        command_args =
          destination_args
          ++ ["copy"]
          ++ source_args
          ++ ["--tag" (concatStringsSep "," (promotion_tags entry role))];
        script = ''
          set -eu
          ${optionalString (from.environment_file != null) ''
            set -a
            . ${escapeShellArg from.environment_file}
            set +a
          ''}
          if ! ${restic} ${render_argv probe_args} >/dev/null 2>&1; then
            ${restic} ${render_argv init_args}
          fi
          exec ${restic} ${render_argv command_args}
        '';
      in {
        services = [
          (mk_service {
            name = service_name;
            inherit (destination) environment_file;
            network_online = needs_network [from destination];
            ssh_runtime = needs_ssh [from destination];
            inherit script;
          })
        ];
        timers = [
          (mk_timer {
            name = service_name;
            timerConfig = entry.policy.promotion_timerConfig;
          })
        ];
      })
      (builtins.filter (role: role != "A") (builtins.attrNames entry.destinations));

    mk_forget_units = entry:
      map (role: let
        destination = entry.destinations.${role};
        role_name = role_suffix role;
        service_name = "backup_forget_${item_stem entry}_on_${role_name}";
        command_args =
          repo_args destination
          ++ ["forget"]
          ++ concatMap split_words entry.forget_args
          ++ ["--tag" (concatStringsSep "," (item_identity_tags entry))];
        script = ''
          set -eu
          exec ${restic} ${render_argv command_args}
        '';
      in {
        services = [
          (mk_service {
            name = service_name;
            inherit (destination) environment_file;
            network_online = needs_network [destination];
            ssh_runtime = needs_ssh [destination];
            inherit script;
          })
        ];
        timers = [
          (mk_timer {
            name = service_name;
            timerConfig = entry.policy.forget_timerConfig;
          })
        ];
      })
      (builtins.attrNames entry.destinations);

    repo_roles = builtins.attrNames resolved_items.repo_maintenance;

    mk_repo_maintenance_units = role: let
      maintenance = resolved_items.repo_maintenance.${role};
      inherit (maintenance) destination;
      role_name = role_suffix role;
      prune_name = "backup_prune_${host_name}_${role_name}";
      check_name = "backup_check_${host_name}_${role_name}";
      prune_args =
        repo_args destination
        ++ ["prune"];
      check_args =
        repo_args destination
        ++ ["check"]
        ++ concatMap split_words maintenance.check_args;
    in {
      services = [
        (mk_service {
          name = prune_name;
          inherit (destination) environment_file;
          network_online = needs_network [destination];
          ssh_runtime = needs_ssh [destination];
          script = ''
            set -eu
            exec ${restic} ${render_argv prune_args}
          '';
        })
        (mk_service {
          name = check_name;
          inherit (destination) environment_file;
          network_online = needs_network [destination];
          ssh_runtime = needs_ssh [destination];
          script = ''
            set -eu
            exec ${restic} ${render_argv check_args}
          '';
        })
      ];
      timers = [
        (mk_timer {
          name = prune_name;
          timerConfig = maintenance.prune_timerConfig;
        })
        (mk_timer {
          name = check_name;
          timerConfig = maintenance.check_timerConfig;
        })
      ];
    };

    rendered_units =
      lib.optionals is_coordinator (flatten (map mk_promotion_units resolved_items.local_to_a))
      ++ flatten (map mk_forget_units resolved_items.local_to_a)
      ++ map mk_repo_maintenance_units repo_roles;

    rendered_services = concatMap (entry: entry.services) rendered_units;
    rendered_timers = concatMap (entry: entry.timers) rendered_units;
  in {
    services = builtins.listToAttrs rendered_services;
    timers = builtins.listToAttrs rendered_timers;
  };
}
