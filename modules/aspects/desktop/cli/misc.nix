_: {
  den.aspects.cli.homeManager = {pkgs, ...}: {
    home.packages = with pkgs; [
      ouch-rar

      ast-grep
      jqp

      just

      sshfs
      lazyssh
      lazyjournal

      clock-rs
    ];
  };
}
