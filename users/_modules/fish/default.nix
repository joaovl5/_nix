let
  inherit (import ../../../_lib/modules) combine_modules;
  modules = [
    (import ./setup.nix)
    (import ./aliases.nix)
  ];
in
  combine_modules modules
