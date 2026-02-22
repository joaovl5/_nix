let
  inherit (import ../../../_lib/modules) combine_modules;
  modules = [
    (import ./librewolf)
  ];
in
  combine_modules modules
