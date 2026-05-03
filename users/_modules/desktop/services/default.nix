let
  inherit (import ../../../../_lib/modules) combine_modules;
  modules = [
    (import ./espanso)
    (import ./kanata)
    (import ./storage)
    (import ./syncthing)
  ];
in
  combine_modules modules
