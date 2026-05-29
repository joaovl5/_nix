{
  inputs,
  self,
  ...
}: let
  system = "x86_64-linux";
  lib = inputs.nixpkgs.lib;

  excluded = [
    "hjem"
    "musnix.kernel.packages"
    "virtualisation.vmVariant.musnix.kernel.packages"
  ];

  parse_path = path_str: lib.splitString "." path_str;

  remove_at_path = path: set:
    if path == []
    then set
    else let
      key = builtins.head path;
      rest = builtins.tail path;
      sub = set.${key} or null;
    in
      if rest == []
      then builtins.removeAttrs set [key]
      else if builtins.isAttrs sub
      then
        set
        // {
          ${key} = remove_at_path rest sub;
        }
      else set;

  remove_nested_attrs = paths: set:
    lib.foldl' (acc: path: remove_at_path (parse_path path) acc) set paths;

  mk_options_list = {
    options,
    transform ? lib.id,
    excluded ? [],
  }: let
    options' = remove_nested_attrs excluded options;
    raw_options = map transform (lib.optionAttrSetToDocList options');
  in
    lib.filter (
      option:
        option.visible
        && !option.internal
        && !(builtins.elem option.name excluded)
    )
    raw_options;

  lavpc = self.nixosConfigurations.lavpc;
  placeholder_user = "‹username›";

  hjem_eval = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      inputs.hjem.nixosModules.default
      {
        users.users.${placeholder_user} = {
          isNormalUser = true;
          home = "/home/placeholder";
        };
      }
    ];
  };
in {
  flake._utils.optnix = {
    nx = mk_options_list {
      inherit (lavpc) options;
      inherit excluded;
    };

    hj = mk_options_list {
      options = hjem_eval.options.hjem;
      excluded = ["_module"];
      transform = option:
        option
        // {
          name = lib.removePrefix "hjem." option.name;
        };
    };

    hm = mk_options_list {
      options = lavpc.options.home-manager.users.type.getSubOptions [];
      excluded = ["_module"];
      transform = option:
        option
        // {
          name = lib.removePrefix "<name>." option.name;
        };
    };
  };
}
