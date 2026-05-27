_: {
  den.aspects.cli.homeManager = {pkgs, ...}: {
    home.packages = with pkgs; [
      ouch-rar

      # searching-related
      ast-grep

      just
    ];
  };
}
