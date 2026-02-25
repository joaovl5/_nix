{
  hm = {
    lib,
    pkgs,
    ...
  }: {
    programs.tmux = {
      enable = true;

      mouse = true;
      clock24 = true;
      disableConfirmationPrompt = true;
      customPaneNavigationAndResize = true;
      focusEvents = true;
      secureSocket = false;

      terminal = "tmux-256color";
      keyMode = "vi";
      shortcut = "a";
      escapeTime = 0;
      baseIndex = 1;
      resizeAmount = 10;
      historyLimit = 10000;

      plugins = with pkgs; [
        tmuxPlugins.better-mouse-mode
      ];

      extraConfig = lib.readFile ./tmux.conf;
    };

    home.shellAliases = {
      ",t" = "tmux";
      ",ta" = "tmux attach";
      ",tl" = "tmux list-sessions";
      ",tk" = "tmux kill-session";
    };
  };
}
