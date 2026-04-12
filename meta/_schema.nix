{lib}: {
  registry,
  hosts,
}: let
  t = lib.types;

  module_type = module:
    t.submoduleWith {
      modules = [
        {inherit (module) options;}
      ];
      shorthandOnlyDefinesConfig = true;
    };

  module_options = lib.mapAttrs (_module_name: module:
    lib.mkOption {
      type = t.nullOr (module_type module);
      default = null;
    })
  registry;

  host_type = t.submoduleWith {
    modules = [
      {
        options.modules = module_options;
      }
    ];
    shorthandOnlyDefinesConfig = true;
  };

  host_modules = host: let
    host_meta = host.meta or {};
  in
    host_meta.modules or {};
in
  lib.evalModules {
    modules = [
      {
        options.hosts = lib.mkOption {
          type = t.attrsOf host_type;
          default = {};
        };
      }
      {
        config.hosts =
          lib.mapAttrs (_host_name: host: {
            modules = host_modules host;
          })
          hosts;
      }
    ];
  }
