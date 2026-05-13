let
  inherit (import ../../../../_lib/modules) combine_modules;
  modules = [
    # keep-sorted start
    (import ./gnome)
    (import ./hyprland)
    (import ./niri)
    # keep-sorted end
  ];
in
  combine_modules modules
