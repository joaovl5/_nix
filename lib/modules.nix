let
  NIXOS_KEY = "nx";
  HOMEMANAGER_KEY = "hm";
  filter_module_attrs = modules: attr:
    map
    (module: module.${attr})
    (builtins.filter
      (module: !isNull (module.${attr} or null))
      modules);
  combine_module_attrs = modules: attr: {
    imports = filter_module_attrs modules attr;
  };
in {
  extract_imports = modules: {
    "${NIXOS_KEY}" = filter_module_attrs modules NIXOS_KEY;
    "${HOMEMANAGER_KEY}" = filter_module_attrs modules HOMEMANAGER_KEY;
  };
  combine_modules = modules: {
    "${NIXOS_KEY}" = combine_module_attrs modules NIXOS_KEY;
    "${HOMEMANAGER_KEY}" = combine_module_attrs modules HOMEMANAGER_KEY;
  };
}
