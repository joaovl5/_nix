let
  inherit (import ../../../../../_lib/modules) combine_modules;
  modules = [
    # keep-sorted start
    (import ./emacs)
    (import ./neovim)
    # keep-sorted end
  ];
in
  combine_modules modules
