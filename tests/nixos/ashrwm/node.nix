{inputs, ...}: {pkgs, ...}: let
  ashrwm = pkgs.callPackage (inputs.ashrwm-src.outPath + "/package.nix") {};
in {
  system.stateVersion = "25.11";

  users.users.tester = {
    isNormalUser = true;
    home = "/home/tester";
  };

  environment = {
    etc."ashrwm/config.janet".source = ./config.janet;
    systemPackages = with pkgs; [
      ashrwm
      foot
      grim
      imagemagick
      wlr-randr
    ];
  };

  fonts.packages = [pkgs.dejavu_fonts];

  systemd.services.ashrwm-test = {
    description = "Ashrwm integration test compositor";
    wantedBy = ["multi-user.target"];
    path = [pkgs.libnotify];
    environment = {
      HOME = "/home/tester";
      XDG_CONFIG_HOME = "/etc";
      XDG_CURRENT_DESKTOP = "ashrwm";
      XDG_RUNTIME_DIR = "/run/ashrwm-test";
      XDG_SESSION_TYPE = "wayland";
      WLR_BACKENDS = "headless";
      WLR_HEADLESS_OUTPUTS = "2";
      WLR_LIBINPUT_NO_DEVICES = "1";
      WLR_RENDERER = "pixman";
    };
    serviceConfig = {
      ExecStart = "${pkgs.river}/bin/river -c ${ashrwm}/bin/ashrwm";
      Group = "users";
      Restart = "on-failure";
      RuntimeDirectory = "ashrwm-test";
      RuntimeDirectoryMode = "0700";
      User = "tester";
    };
  };

  virtualisation = {
    cores = 2;
    memorySize = 2048;
  };
}
