let
  inherit (import ../../../_lib/modules.nix) combine_modules;
  modules = [
    (import ./zoxide.nix)
    (import ./eza.nix)
    (import ./bat.nix)
    (import ./fzf.nix)
    (import ./nix-tools.nix)
    (import ./lazygit.nix)
    (import ./tmux)
    (import ./zellij)
  ];
in
  combine_modules modules
