let
  inherit (import ../../../../_lib/modules) combine_modules;
  modules = [
    # keep-sorted start
    (import ./espanso)
    (import ./kanata)
    (import ./storage)
    (import ./syncthing)
    # keep-sorted end
  ];
in
  combine_modules modules
