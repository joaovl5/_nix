{
  lib,
  config,
  pkgs,
  ...
}: let
  types = import ./types.nix {inherit lib;};

  sanitize = value:
    lib.replaceStrings ["/" "." " " "_" "-"] ["-" "-" "-" "-" "_"] value;

  sanitize_local_job_name = value:
    lib.replaceStrings ["/" "." " " "-"] ["_" "_" "_" "_"] value;

  secret_root = "${builtins.dirOf config.sops.defaultSopsFile}/secrets";

  render_secret = secret_ref: {
    key = lib.mkDefault secret_ref.key;
    sopsFile = lib.mkDefault "${secret_root}/${secret_ref.file}";
    owner = lib.mkDefault "root";
    group = lib.mkDefault "root";
    mode = lib.mkDefault "0400";
  };

  expand_repository_fn = {
    template,
    source_host,
  }:
    lib.replaceStrings ["{host}"] [source_host] template;

  mk_destination_record = {
    role,
    source_host,
    destination,
  }: {
    inherit role;
    inherit (destination) backend extra_options;
    repository = expand_repository_fn {
      template = destination.repository_template;
      inherit source_host;
    };
    password_file =
      if destination.password_secret == null
      then null
      else config.sops.secrets.${destination.password_secret.name}.path;
    environment_file =
      if destination.environment_secret == null
      then null
      else config.sops.secrets.${destination.environment_secret.name}.path;
  };

  mk_tag_args = tags: lib.concatMap (tag: ["--tag" tag]) tags;

  mk_job_name_fn = {
    source_host,
    unit_name,
    item_name,
    suffix,
  }:
    lib.concatStringsSep "_" (map sanitize [source_host unit_name item_name suffix]);

  mk_local_job_name_fn = {
    source_host,
    unit_name,
    item_name,
    suffix,
  }:
    lib.concatStringsSep "_" (
      map sanitize_local_job_name (
        [source_host]
        ++ lib.optional (unit_name != "host") unit_name
        ++ [item_name suffix]
      )
    );

  choose_mode = values:
    if values == []
    then {}
    else let
      counts =
        builtins.foldl' (
          acc: value: let
            key = builtins.toJSON value;
            previous = acc.${key}.count or 0;
          in
            acc
            // {
              ${key} = {
                inherit value;
                count = previous + 1;
              };
            }
        ) {}
        values;
      ranked = builtins.attrValues counts;
      best =
        builtins.foldl' (
          current: candidate:
            if current == null || candidate.count > current.count
            then candidate
            else current
        )
        null
        ranked;
    in
      best.value;

  read_subset_value = arg: let
    match = builtins.match "--read-data-subset=([0-9]+)%" arg;
  in
    if match == null
    then null
    else lib.toInt (builtins.head match);

  merge_check_args = arg_lists: let
    flattened = lib.concatLists arg_lists;
    plain_args = lib.unique (builtins.filter (arg: read_subset_value arg == null) flattened);
    read_subset_args = builtins.filter (arg: read_subset_value arg != null) flattened;
    strongest_subset =
      builtins.foldl' (
        current: arg:
          if current == null || read_subset_value arg > read_subset_value current
          then arg
          else current
      )
      null
      read_subset_args;
  in
    plain_args ++ lib.optional (strongest_subset != null) strongest_subset;

  payload_paths = item:
    if item.kind == "path"
    then item.path.paths
    else if item.kind == "btrfs_snapshot"
    then [item.btrfs_snapshot.snapshot_path]
    else [];

  secret_path_or_fallback = secret_name:
    if builtins.hasAttr secret_name config.sops.secrets
    then config.sops.secrets.${secret_name}.path
    else "/run/secrets/${secret_name}";

  default_stdin_filename = {
    source_host,
    unit_name,
    item_name,
    kind,
  }: "${mk_job_name_fn {
    inherit source_host unit_name item_name;
    suffix = kind;
  }}.sql";

  payload_command = entry: let
    inherit (entry) item;
    shell_name = mk_job_name_fn {
      inherit (entry) source_host unit_name item_name;
      suffix = "${item.kind}_command";
    };
  in
    if item.kind == "custom"
    then [
      (pkgs.writeShellScript shell_name item.custom.command)
    ]
    else if item.kind == "postgres_dump"
    then [
      (pkgs.writeShellScript shell_name ''
        exec ${pkgs.postgresql}/bin/pg_dump ${lib.escapeShellArg item.postgres_dump.database}
      '')
    ]
    else if item.kind == "mysql_dump"
    then [
      (pkgs.writeShellScript shell_name ''
        MYSQL_PWD=$(cat ${lib.escapeShellArg (secret_path_or_fallback item.mysql_dump.password_secret.name)})
        export MYSQL_PWD
        exec ${pkgs.mariadb}/bin/mysqldump \
          --host=${lib.escapeShellArg item.mysql_dump.host} \
          --port=${toString item.mysql_dump.port} \
          --user=${lib.escapeShellArg item.mysql_dump.username} \
          ${lib.escapeShellArg item.mysql_dump.database}
      '')
    ]
    else null;

  payload_stdin_filename = entry: let
    inherit (entry) item;
  in
    if item.kind == "custom"
    then
      if item.custom.stdin_filename != null
      then item.custom.stdin_filename
      else
        default_stdin_filename {
          inherit (entry) source_host unit_name item_name;
          inherit (item) kind;
        }
    else if item.kind == "postgres_dump" || item.kind == "mysql_dump"
    then
      default_stdin_filename {
        inherit (entry) source_host unit_name item_name;
        inherit (item) kind;
      }
    else null;

  touched_roles_for_item = {
    destinations,
    promote_to,
  }:
    builtins.filter (role: destinations.${role}.enable) (lib.unique (["A"] ++ promote_to));
in rec {
  inherit types;

  render_destination_secrets = destinations:
    lib.foldl' (
      acc: role: let
        destination = destinations.${role};
        add_secret = secret_ref:
          if (!destination.enable) || secret_ref == null
          then {}
          else {
            ${secret_ref.name} = render_secret secret_ref;
          };
      in
        acc
        // add_secret destination.password_secret
        // add_secret destination.environment_secret
    ) {} (builtins.attrNames destinations);

  render_item_secrets = items:
    lib.foldl' (
      acc: entry: let
        inherit (entry) item;
        mysql_secret =
          if item.kind == "mysql_dump"
          then item.mysql_dump.password_secret
          else null;
      in
        acc
        // (
          if mysql_secret == null
          then {}
          else {
            ${mysql_secret.name} = render_secret mysql_secret;
          }
        )
    ) {}
    items;

  render_backup_secrets = {
    destinations,
    items,
  }:
    render_destination_secrets destinations
    // render_item_secrets items;

  expand_repository = expand_repository_fn;

  mk_item_tags = {
    source_host,
    unit_name,
    item_name,
    promote_to ? [],
    extra_tags ? [],
  }:
    lib.unique (
      [
        "host:${source_host}"
        "unit:${unit_name}"
        "item:${item_name}"
      ]
      ++ map (role: "promote:${role}") promote_to
      ++ extra_tags
    );

  mk_job_name = {
    source_host,
    unit_name,
    item_name,
    suffix,
  }:
    mk_job_name_fn {
      inherit source_host unit_name item_name suffix;
    };

  resolve_items = {
    host_name,
    destinations,
    policies,
    items,
  }: let
    enabled_items = builtins.filter (entry: entry.item.enable) items;

    resolve_entry = entry: let
      inherit (entry) item;
      policy = policies.${item.policy};
      effective_promote_to =
        if item.promote_to != null
        then item.promote_to
        else policy.promote_to;
      tags = mk_item_tags {
        inherit (entry) source_host;
        inherit (entry) unit_name item_name;
        promote_to = effective_promote_to;
        extra_tags = item.tags;
      };
      touched_roles = touched_roles_for_item {
        inherit destinations;
        promote_to = effective_promote_to;
      };
      resolved_destinations = builtins.listToAttrs (map (role: {
          name = role;
          value = mk_destination_record {
            inherit role;
            inherit (entry) source_host;
            destination = destinations.${role};
          };
        })
        touched_roles);
      forget_args =
        if item.retention != null
        then item.retention
        else policy.forget;
    in {
      inherit (entry) item_name source_host unit_name;
      policy_name = item.policy;
      job_name = mk_job_name {
        inherit (entry) source_host;
        inherit (entry) unit_name item_name;
        suffix = "to_a";
      };
      local_job_name = mk_local_job_name_fn {
        inherit (entry) source_host;
        inherit (entry) unit_name item_name;
        suffix = "to_a";
      };
      payload_user =
        if item.kind == "postgres_dump" && item.run_as_user != "root"
        then item.run_as_user
        else null;
      service_user =
        if item.kind == "postgres_dump" && item.run_as_user != "root"
        then "root"
        else item.run_as_user;
      timerConfig =
        if item.schedule != null
        then item.schedule
        else policy.timerConfig;
      inherit policy;
      destinations = resolved_destinations;
      inherit tags;
      tag_args = mk_tag_args tags;
      prepare_command = item.prepare;
      cleanup_command = item.cleanup;
      inherit forget_args;
      stdin_filename = payload_stdin_filename entry;
      paths = payload_paths item;
      command = payload_command entry;
      payload = item.${item.kind};
      inherit (item) kind;
    };

    local_to_a = map resolve_entry enabled_items;
    touched_roles = lib.unique (lib.concatMap (item: builtins.attrNames item.destinations) local_to_a);
    repo_maintenance = builtins.listToAttrs (map (
        role: let
          role_items = builtins.filter (item: builtins.hasAttr role item.destinations) local_to_a;
          role_destination = destinations.${role};
          prune_timers = map (item: item.policy.prune_timerConfig) role_items;
          check_timers = map (item: item.policy.check_timerConfig) role_items;
          check_args = map (item: item.policy.check) role_items;
        in {
          name = role;
          value = {
            destination = mk_destination_record {
              inherit role;
              source_host = host_name;
              destination = role_destination;
            };
            prune_timerConfig = choose_mode prune_timers;
            check_timerConfig = choose_mode check_timers;
            check_args = merge_check_args check_args;
            item_names = map (item: item.item_name) role_items;
          };
        }
      )
      touched_roles);
  in {
    inherit local_to_a repo_maintenance;
  };
}
