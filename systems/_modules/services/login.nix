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
    enable = false;
  };

  # services.displayManager.sddm = {
  #   enable = true;
  #   wayland = {
  #     enable = true;
  #     compositorCommand = ''
  #       ${lib.getExe pkgs.kdePackages.kwin "kwin_wayland"} \
  #         --drm \
  #         --no-lockscreen \
  #         --no-global-shortcuts \
  #         --locale1
  #     '';
  #   };
  #   theme = "catppuccin-mocha-mauve";
  # };

  # environment.systemPackages = [
  #   (pkgs.catppuccin-sddm.override {
  #     flavor = "mocha";
  #     accent = "mauve";
  #   })
  # ];
}
