let
  inherit (import ../../../lib/modules.nix) combine_modules;
  modules = [
    (import ./langs/js.nix)
  ];
in
  combine_modules modules
