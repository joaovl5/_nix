let
  inherit (import ../../../../_lib/modules) combine_modules;
  modules = [
    (import ./tmux)
    (import ./zellij)
  ];
in
  combine_modules modules
