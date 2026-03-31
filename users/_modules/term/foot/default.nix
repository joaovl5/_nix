{
  hm = _: let
    foot_theme = {
      background = "1a1b26";
      foreground = "c0caf5";
      regular0 = "15161E";
      regular1 = "f7768e";
      regular2 = "9ece6a";
      regular3 = "e0af68";
      regular4 = "7aa2f7";
      regular5 = "bb9af7";
      regular6 = "7dcfff";
      regular7 = "c0caf5";
      bright0 = "2f313d";
      bright1 = "ff9e64";
      bright2 = "9ece6a";
      bright3 = "f9e2af";
      bright4 = "7aa2f7";
      bright5 = "bb9af7";
      bright6 = "7dcfff";
      bright7 = "a9b1d6";
      dim0 = "15161e";
      dim1 = "f7768e";
      dim2 = "9ece6a";
      dim3 = "e0af68";
      dim4 = "7aa2f7";
      dim5 = "bb9af7";
      dim6 = "7dcfff";
      dim7 = "565f89";
      selection-foreground = "1a1b26";
      selection-background = "7aa2f7";
      alpha = 1;
      cursor = "1a1b26 c0caf5";
    };
  in {
    programs.foot = {
      enable = true;
      server.enable = true;
      settings = {
        main = {
          font = "Iosevka Nerd Font:size=15";
          pad = "25x17 center-when-maximized-and-fullscreen";
          dpi-aware = true;
          resize-keep-grid = false;
        };
        bell = {
          system = true;
          notify = true;
          visual = true;
        };
        scrollback = {
          lines = 100000;
        };
        cursor = {
          style = "underline";
        };
        mouse = {
          hide-when-typing = true;
        };
        csd = {
          preferred = "none";
          size = 0;
        };
        colors-dark = foot_theme;
        key-bindings = {
          font-increase = "Alt+equal";
          font-decrease = "Alt+minus";
          scrollback-up-page = "Alt+bracketleft";
          scrollback-down-page = "Alt+bracketright";
          clipboard-copy = "Alt+c";
          clipboard-paste = "Alt+v";
        };
      };
    };
  };
}
