let
  inherit (import ../../../lib/modules.nix) combine_modules;
  modules = [
    (import ./setup.nix)
    (import ./aliases.nix)
    (import ./secrets.nix)
  ];
in
  combine_modules modules
