_: {
  den.aspects.cli.homeManager = {pkgs, ...}: {
    shell-abbrs = {
      "tar" = "ouch d";
      "zip" = "ouch d";
      "w" = "just";
    };

    home.packages = with pkgs; [
      ouch-rar

      ast-grep

      just

      sshfs
      lazyssh
      lazyjournal

      clock-rs
    ];
  };
}
