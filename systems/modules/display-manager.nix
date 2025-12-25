{
  pkgs,
  default_cmd,
  ...
}: {
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
        tuigreet = "${pkgs.tuigreet}/bin/tuigreet";
        cmd = default_cmd;
      in {
        command = "${tuigreet} --time --remember --cmd ${cmd}";
      };
    };
  };
}
