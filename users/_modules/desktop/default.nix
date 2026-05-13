let
  inherit (import ../../../_lib/modules) combine_modules;
  modules = [
    # keep-sorted start
    (import ./apps)
    (import ./audio)
    (import ./fonts.nix)
    (import ./gtk)
    (import ./hexecute)
    (import ./launcher)
    (import ./services)
    (import ./whisper-overlay)
    (import ./widgets)
    (import ./wm)
    (import ./xdg-portals.nix)
    # keep-sorted end
  ];
in
  combine_modules modules
