{lib, ...}: let
  inherit (lib) mkOption types;
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
      type = types.path;
      default = "shared";
    };
    private_data_dirname = mkOption {
      description = "Name of directory from which private data will reside, will get prepended to $HOME";
      type = types.str;
      default = "private";
    };
  };
}
