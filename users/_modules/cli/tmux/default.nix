{
  hm = {
    lib,
    pkgs,
    ...
  }: let
    shared = import ./shared.nix {inherit lib pkgs;};
  in {
    programs.tmux = shared.mkTmuxProgram {};

    home.shellAliases = shared.shellAliases;
  };
}
