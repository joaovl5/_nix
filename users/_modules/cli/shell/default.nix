let
  inherit (import ../../../../_lib/modules) combine_modules;
  modules = [
    # keep-sorted start
    (import ./fish)
    (import ./nushell)
    # keep-sorted end
  ];
in
  combine_modules modules
