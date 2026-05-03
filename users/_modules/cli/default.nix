let
  inherit (import ../../../_lib/modules) combine_modules;
  modules = [
    (import ./zoxide.nix)
    (import ./eza.nix)
    (import ./bat.nix)
    (import ./fzf.nix)
    (import ./ssh.nix)
    (import ./fetchers)
    (import ./nix-tools.nix)
    (import ./lazygit.nix)
    (import ./tmux)
    (import ./zellij)
    (import ./hister.nix)
  ];
in
  combine_modules modules
