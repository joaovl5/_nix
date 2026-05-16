let
  inherit (import ../../../../_lib/modules) combine_modules;
  modules = [
    # keep-sorted start
    (import ./fennel.nix)
    (import ./janet.nix)
    (import ./js.nix)
    (import ./lua.nix)
    (import ./nix.nix)
    (import ./python.nix)
    (import ./sql.nix)
    # keep-sorted end
  ];
in
  combine_modules modules
