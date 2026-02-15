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
      ## tmux
      "t" = "tmux";
      "t.a" = "tmux attach";
      "t.l" = "tmux list-sessions";
      "t.k" = "tmux kill-session";
      ## systemd
      "s" = "systemctl";
      "s.s" = "systemctl status";
      "s.r" = "systemctl restart";
      "s.S" = "systemctl stop";
      "su" = "systemctl --user";
      "su.s" = "systemctl --user status";
      "su.r" = "systemctl --user restart";
      "su.S" = "systemctl --user stop";
      "j.u" = "journalctl --user -xeu";
    };
  }))
