let
  inherit (import ../../../_lib/modules) combine_modules;
  modules = [
    (import ./wm)
    (import ./widgets)
    (import ./launcher)
    (import ./hexecute)
    (import ./whisper-overlay)
    (import ./gtk)
    (import ./fonts.nix)
    (import ./xdg-portals.nix)
    (import ./audio)
    (import ./apps)
    (import ./services)
  ];
in
  combine_modules modules
