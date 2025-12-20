{...}: {
  # tty-based manager
  services.sysc-greet = {
    enable = true;
  };
  # systemd.services.greetd.serviceConfig = {
  #   Type = "idle";
  #   StandardInput = "tty";
  #   StandardOutput = "tty";
  #   StandardError = "journal";
  #   TTYReset = true;
  #   TTYVHangup = true;
  #   TTYVTDisallocate = true;
  # };
  #
  # services.greetd = {
  #   enable = true;
  #   settings = {
  #     default_session = "";
  #   };
  # };
}
