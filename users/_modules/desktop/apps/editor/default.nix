let
  inherit (import ../../../../../_lib/modules) combine_modules;
  modules = [
    (import ./emacs)
    (import ./neovim)
  ];
in
  combine_modules modules
