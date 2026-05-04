let
  inherit (import ../../../../_lib/modules) combine_modules;
  modules = [
    (import ./niri)
    (import ./gnome)
    (import ./hyprland)
  ];
in
  combine_modules modules
