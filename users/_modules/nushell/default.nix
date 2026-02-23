let
  inherit (import ../../../_lib/modules) combine_modules;
  modules = [
    (import ./setup.nix)
    (import ./env.nix)
  ];
in
  combine_modules modules
