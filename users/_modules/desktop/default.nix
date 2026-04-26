let
  inherit (import ../../../_lib/modules) combine_modules;
  modules = [
    (import ./niri)
    (import ./eww)
    (import ./gnome)
    (import ./anyrun)
    (import ./hexecute)
    (import ./hyprland)
    (import ./gtk)
    (import ./xdg-portals.nix)
  ];
in
  combine_modules modules
