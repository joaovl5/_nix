let
  inherit (import ../../../../_lib/modules) combine_modules;
  modules = [
    # keep-sorted start
    (import ./_misc.nix)
    (import ./fennel.nix)
    (import ./janet.nix)
    (import ./js.nix)
    (import ./json.nix)
    (import ./lua.nix)
    (import ./nim.nix)
    (import ./nix.nix)
    (import ./python.nix)
    (import ./rust.nix)
    (import ./shell.nix)
    (import ./sql.nix)
    (import ./toml.nix)
    (import ./yaml.nix)
    # keep-sorted end
  ];
in
  combine_modules modules
