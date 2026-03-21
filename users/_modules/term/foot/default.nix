{
  hm = _: {
    programs.foot = {
      enable = true;
      server.enable = true;
      settings = {
        main = {
          font = "FiraCode Nerd Font Med:size=15";
          pad = "0x0";
          hide-when-typing = true;
        };
        scrollback = {
          lines = 100000;
        };
        cursor = {
          style = "underline";
        };
        key-bindings = {
          quit = "Alt+q";
          reload-config = "Alt+Shift+0";
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
