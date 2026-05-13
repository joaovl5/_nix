let
  inherit (import ../../../_lib/modules) combine_modules;
  modules = [
    # keep-sorted start
    (import ./bat.nix)
    (import ./eza.nix)
    (import ./fetchers)
    (import ./fzf.nix)
    (import ./hister.nix)
    (import ./lazygit.nix)
    (import ./misc.nix)
    (import ./multiplexer)
    (import ./nix-tools.nix)
    (import ./shell)
    (import ./ssh.nix)
    (import ./starship)
    (import ./yazi)
    (import ./zoxide.nix)
    # keep-sorted end
  ];
in
  combine_modules modules
