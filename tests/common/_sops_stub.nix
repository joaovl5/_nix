{lib, ...}: {
  options.sops = {
    defaultSopsFile = lib.mkOption {
      type = lib.types.path;
      default = /dev/null;
    };
    secrets = lib.mkOption {
      default = {};
      type = lib.types.attrsOf (lib.types.submodule ({name, ...}: {
        options = {
          path = lib.mkOption {
            type = lib.types.str;
            default = "/run/secrets/${name}";
            readOnly = true;
          };
          owner = lib.mkOption {
            type = lib.types.str;
            default = "root";
          };
          group = lib.mkOption {
            type = lib.types.str;
            default = "root";
          };
          mode = lib.mkOption {
            type = lib.types.str;
            default = "0400";
          };
          key = lib.mkOption {
            type = lib.types.str;
            default = name;
          };
          sopsFile = lib.mkOption {
            type = lib.types.path;
            default = /dev/null;
          };
        };
      }));
    };
    age.sshKeyPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
    };
  };
}
