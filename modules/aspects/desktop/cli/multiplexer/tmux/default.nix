{lav, ...}: {
  den.aspects.cli.homeManager = {
    lib,
    pkgs,
    ...
  }: let
    shared = lav.cli.multiplexer.tmux.shared {inherit lib pkgs;};
  in {
    programs.tmux = shared.mkTmuxProgram {};

    home.shellAliases = shared.shellAliases;
  };
}
