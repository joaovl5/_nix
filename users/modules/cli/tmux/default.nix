{
  hm = {lib, ...}: {
    programs.tmux = {
      enable = true;

      mouse = true;
      clock24 = true;
      disableConfirmationPrompt = true;
      customPaneNavigationAndResize = true;
      focusEvents = true;

      terminal = "tmux-256color";
      keyMode = "vi";
      shortcut = "d";
      escapeTime = 10;
      baseIndex = 1;
      resizeAmount = 10;
      historyLimit = 10000;
      extraConfig = lib.readFile ./tmux.conf;
    };
  };
}
