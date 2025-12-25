{pkgs, ...}: {
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

  services.greetd = {
    enable = true;
    settings = {
      default_session = let
        greeter = "${pkgs.tuigreet}/bin/tuigreet --time --cmd ";
      in {
        # .wayland-session - set by hm modules for wayland compositors
        command = "${greeter} $HOME/.wayland-session";
      };
    };
  };
}
