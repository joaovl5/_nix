{
  lib,
  pkgs,
}: let
  baseConfig = lib.readFile ./tmux.conf;
  joinConfig = fragments:
    lib.concatStringsSep "\n\n" (lib.filter (fragment: fragment != "") fragments);
in {
  mkTmuxProgram = {
    extraConfig ? "",
    extraPlugins ? [],
  }: {
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

    plugins = with pkgs;
      [
        tmuxPlugins.better-mouse-mode
      ]
      ++ extraPlugins;

    extraConfig = joinConfig ([baseConfig] ++ lib.optional (extraConfig != "") extraConfig);
  };

  shellAliases = {
    ",t" = "tmux";
    ",ta" = "tmux attach";
    ",tl" = "tmux list-sessions";
    ",tk" = "tmux kill-session";
  };
}
