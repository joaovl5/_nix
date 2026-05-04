let
  inherit (import ../../../../../_lib/modules) combine_modules;
  modules = [
    (import ./obs)
    (import ./stremio)
  ];
in
  combine_modules modules
