_: {
  den.aspects.desktop.homeManager.services.kanshi = {
    enable = true;
    settings = [
      {
        profile = {
          name = "desktop";
          outputs = [
            {
              criteria = "DP-4";
              mode = "3840x2160@240.080Hz";
              position = "1080,396";
              scale = 1.333333;
            }
            {
              criteria = "HDMI-A-2";
              mode = "1920x1080@100Hz";
              position = "0,240";
              transform = "90";
            }
          ];
        };
      }
    ];
  };
}
