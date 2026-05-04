let
  inherit (import ../../../../_lib/modules) combine_modules;
  modules = [
    (import ./fish)
    (import ./nushell)
  ];
in
  combine_modules modules
