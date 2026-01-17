{
  pkgs,
  config,
  ...
}: let
  cfg = config.my_nix;
  home_path = config.users.users.${cfg.username}.home;
in {
  # tty-based manager
  systemd.services.greetd.serviceConfig = {
    Type = "idle";
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "journal";
    TTYReset = true;
    TTYVHangup = true;
    TTYVTDisallocate = true;
  };

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "catppuccin-mocha-mauve";
  };

  environment.systemPackages = [ 
    (pkgs.catppuccin-sddm.override {
      flavor = "mocha";
      accent = "mauve";
    })
  ];

  services.greetd = {
    enable = false;
    settings = {
      default_session = let
        greeter = "${pkgs.tuigreet}/bin/tuigreet --time --cmd ";
      in {
        # .wayland-session - set by hm modules for wayland compositors
        command = "${greeter} ${home_path}/.wayland-session";
      };
    };
  };
}
