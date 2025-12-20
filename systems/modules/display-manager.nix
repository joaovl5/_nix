{
  lib,
  pkgs,
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
        tuigreet = "${lib.exe pkgs.tuigreet}";
      in {
        command = "${tuigreet} --time --remember";
      };
    };
  };
}
