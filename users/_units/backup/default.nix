{
  mylib,
  config,
  lib,
  pkgs,
  ...
}: let
  my = mylib.use config;
  u = my.units;
  inherit (lib) filter hasAttr hasPrefix mkIf mkOption nameValuePair removePrefix;
  t = lib.types;

  cfg = config.my."unit.backup";
  host_name = config.my.nix.hostname;
  collect = import ./_collect.nix;
  render_local = import ./_render_local.nix;
  render_promotion = import ./_render_promotion.nix;

  unit_items = builtins.listToAttrs (map (
      option_name:
        nameValuePair (removePrefix "unit." option_name) config.my.${option_name}.backup.items
    )
    (filter (
      option_name:
        hasPrefix "unit." option_name
        && option_name != "unit.backup"
        && hasAttr "backup" config.my.${option_name}
    ) (builtins.attrNames config.my)));

  collected = collect {
    inherit u host_name;
    inherit (cfg) destinations policies;
    inherit unit_items;
    inherit (cfg) host_items;
  };

  rendered = render_promotion {
    inherit lib pkgs config;
    inherit (collected) resolved_items;
  };
in {
  options.my."unit.backup" = {
    enable = mkOption {
      type = t.bool;
      default = false;
    };
    state_dir = mkOption {
      type = t.str;
      default = "/var/lib/backups";
    };
    coordinator_host = mkOption {
      type = t.str;
      default = host_name;
    };
    destinations = mkOption {
      type = t.attrsOf u.backup.types.BackupDestination;
      default = {};
    };
    policies = mkOption {
      type = t.attrsOf u.backup.types.BackupPolicy;
      default = {};
    };
    host_items = mkOption {
      type = t.attrsOf u.backup.types.BackupItem;
      default = {};
    };
    resolved_items = mkOption {
      type = t.anything;
      readOnly = true;
    };
    rendered = mkOption {
      type = t.anything;
      readOnly = true;
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.hasAttr "A" cfg.destinations && cfg.destinations.A.enable;
        message = "my.unit.backup requires destination role A to be enabled when backups are enabled.";
      }
    ];

    sops.secrets = u.backup.render_backup_secrets {
      inherit (cfg) destinations;
      items = collected.collected_items;
    };

    my."unit.backup" = {
      inherit (collected) resolved_items;
      inherit rendered;
    };

    services.restic.backups = render_local {
      inherit lib pkgs;
      inherit (collected) resolved_items;
    };

    systemd.services = rendered.services;
    systemd.timers = rendered.timers;
  };
}
