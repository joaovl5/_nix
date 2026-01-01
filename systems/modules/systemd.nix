{...}: {
  # See https://www.freedesktop.org/software/systemd/man/journald.conf.html#SystemMaxUse=
  services.journald.extraConfig = ''
    SystemMaxUse=2G
    SystemKeepFree=4G
    SystemMaxFileSize=100M
    MaxFileSec=day
  '';
}
