{
  mylib,
  config,
  ...
}: let
  my = mylib.use config;
  o = my.options;
in
  o.module "shell-aliases" (with o; {
    enable = toggle "Enable preset shell aliases" true;
  }) {} (opts: (o.when opts.enable {
    environment.shellAliases = {
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      "....." = "cd ../../../..";
      "grep" = "grep --color=auto";
      "q" = "exit";
      ":q" = "exit";
      # replacing cmds
      # ls -> eza replacements already handled by home-manager
      "mv" = "mv -v";
      "mkdir" = "mkdir -v";
      "cp" = "cp -v";

      # apps
      ## nvim
      "n" = "nvim";
      ## systemd
      ",s" = "systemctl";
      ",ss" = "systemctl status";
      ",sr" = "systemctl restart";
      ",sS" = "systemctl stop";
      ",sj" = "journalctl -fxe --unit";
      ",u" = "systemctl --user";
      ",us" = "systemctl --user status";
      ",ur" = "systemctl --user restart";
      ",uS" = "systemctl --user stop";
      ",uj" = "journalctl -fxe --user-unit";
    };
  }))
