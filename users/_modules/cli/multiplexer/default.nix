let
  inherit (import ../../../../_lib/modules) combine_modules;
  modules = [
    # keep-sorted start
    (import ./tmux)
    (import ./zellij)
    # keep-sorted end
  ];
in
  combine_modules modules
