let
  inherit (import ../../../../_lib/modules) combine_modules;
  modules = [
    (import ./js.nix)
    (import ./python.nix)
    (import ./fennel.nix)
    (import ./lua.nix)
    (import ./nix.nix)
  ];
in
  combine_modules modules
