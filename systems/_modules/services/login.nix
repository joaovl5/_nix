_: {
  services.xserver.xrandrHeads = let
    main = "DP-4";
    side = "HDMI-A-2";
  in [
    {
      output = main;
      primary = true;
    }
    {
      output = side;
    }
  ];

  services.displayManager.ly = {
    enable = true;
    settings = {
      animation = "doom";
      # dur_file_path = "${../../../_assets/blackhole-smooth-240x67.dur}";

      bigclock = "en";
      text_in_center = true;
      vi_mode = true;

      clear_password = true;
    };
  };
}
