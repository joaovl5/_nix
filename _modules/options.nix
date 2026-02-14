{
  lib,
  config,
  ...
}: let
  inherit (lib) mkOption types;
  cfg = config.my_nix;

  # TODO: ^0 - attempt to use `users.users.<name>.home` later - currently it's failing due to eager eval issues
  # will break when using a mac
  user_home = "/home/${cfg.username}";
in {
  options.my_nix = {
    # system-level
    hostname = mkOption {
      description = "System hostname";
      type = types.str;
    };
    timezone = mkOption {
      description = "System timezone";
      type = types.str;
      default = "America/Sao_Paulo";
    };

    flake_location = mkOption {
      description = "Location where flake for system will reside";
      type = types.str;
      default = "${user_home}/my_nix";
    };

    # servers
    is_server = mkOption {
      description = "Enable to activate certain server-specific tweaks not meant for desktops";
      type = types.bool;
      default = false;
    };

    # desktops
    monitor_layout = mkOption {
      description = "Fixed layout for monitor(s)";
      # todo: type this with submodules
      type = types.nullOr types.attrs;
      default = null;
      /*
      Expected form:
      {
        "DP-4" = {
            primary = true;
            resolution = "3840x2160";
            refresh = "240.08";
            scaling = "1.333333";
          };
      }

      */
    };

    # user-level
    username = mkOption {
      description = "Name for the admin user";
      type = types.str;
    };

    email = mkOption {
      description = "Email for admin user";
      type = types.str;
    };
    name = mkOption {
      description = "First name for admin user";
      type = types.str;
    };

    shared_data_dirname = mkOption {
      description = "Name of directory from which shared data will reside, will get prepended to $HOME";
      type = types.str;
      default = ".sync";
    };
    private_data_dirname = mkOption {
      description = "Name of directory from which private data will reside, will get prepended to $HOME";
      type = types.str;
      default = "private";
    };
  };
}
