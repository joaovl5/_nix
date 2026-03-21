{
  hm = _: {
    programs.foot = {
      enable = true;
      server.enable = true;
      settings = {
        main = {
          font = "FiraCode Nerd Font:size=15";
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
        tweak = {
          allow-overflowing-double-width-glyphs = true;
        };
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
