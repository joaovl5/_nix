let
  NIXOS_KEY = "nx";
  HOMEMANAGER_KEY = "hm";
  filter_module_attrs = modules: attr:
    map
    (module: module.${attr})
    (builtins.filter
      (module: !isNull (module.${attr} or null))
      modules);
  combine_module_attrs = modules: attr: {lib, ...} @ args:
    lib.mkMerge (map
      (module: module.${attr} args)
      (builtins.filter
        (module: !isNull (module.${attr} or null))
        modules));
in {
  extract_imports = modules: {
    "${NIXOS_KEY}" = filter_module_attrs NIXOS_KEY;
    "${HOMEMANAGER_KEY}" = filter_module_attrs HOMEMANAGER_KEY;
  };
  combine_modules = modules: {
    "${NIXOS_KEY}" = combine_module_attrs NIXOS_KEY;
    "${HOMEMANAGER_KEY}" = combine_module_attrs HOMEMANAGER_KEY;
  };
}
