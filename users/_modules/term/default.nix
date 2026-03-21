let
  inherit (import ../../../_lib/modules) combine_modules;
  modules = [
    (import ./ghostty)
    (import ./foot)
  ];
in
  combine_modules modules
