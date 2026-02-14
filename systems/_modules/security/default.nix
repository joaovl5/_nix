{lib, ...}: {
  imports = [
    # TODO: ^0 test later
    # ./kernel.nix
  ];

  security = {
    polkit = {
      enable = true;
      extraConfig = ''
        ${lib.readFile ./polkit-rules/run0.js}
      '';
    };

    sudo.enable = false;
    run0.enableSudoAlias = true;
    soteria.enable = true;
  };

  # Systemd Hardening/tweaks
  ## Handling logs
  services.logrotate.enable = true;
  services.journald = {
    storage = "volatile"; # in-memory logs only
    upload.enable = false; # disable remotely upload logs -- change later
    extraConfig = ''
      SystemMaxUse=500M
      SystemMaxFileSize=50M
    '';
  };
  ## Disable Coredumps
  systemd.coredump.enable = false;
  security.pam.loginLimits = [
    {
      domain = "*"; # applies to all users/sessions
      type = "-"; # set both soft and hard limits
      item = "core"; # the soft/hard limit item
      value = "0"; # core dumps size is limited to 0 (effectively disabled)
    }
  ];
}
