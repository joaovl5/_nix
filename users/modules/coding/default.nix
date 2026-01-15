let
  inherit (import ../../../lib/modules.nix) combine_modules;
  modules = [
    (import ./langs/js.nix)
    (import ./langs/python.nix)
    (import ./langs/fennel.nix)
    (import ./langs/lua.nix)
    (import ./langs/nix.nix)
  ];
in
  combine_modules modules
