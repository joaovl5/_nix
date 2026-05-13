let
  inherit (import ../../../../../_lib/modules) combine_modules;
  modules = [
    # keep-sorted start
    (import ./env.nix)
    (import ./setup.nix)
    # keep-sorted end
  ];
in
  combine_modules modules
