_: {
  lib,
  self,
  test_ssh_key,
  ...
}: {
  imports = [
    ../../_modules/options.nix
  ];

  nixpkgs.overlays = self._channels.overlays;
  system.stateVersion = "25.11";

  my.nix.hostname = "storage";
  my.nix.username = "tester";

  services.openssh = {
    enable = true;
    ports = [59222];
    settings.PasswordAuthentication = false;
  };

  # This fixture user is the only SSH principal repo B accepts during the test.
  users.users.backup-user = {
    isNormalUser = true;
    home = "/home/backup-user";
    createHome = true;
    openssh.authorizedKeys.keyFiles = ["${test_ssh_key}/id_ed25519.pub"];
  };

  # Provision repo B ahead of time so failures come from promotion/maintenance,
  # not missing storage-side directories.
  system.activationScripts."backup-repos-dir" = lib.stringAfter ["users"] ''
    mkdir -p /var/lib/backups/repos/coordinator
    chown -R backup-user /var/lib/backups/repos
    chmod 755 /var/lib/backups /var/lib/backups/repos /var/lib/backups/repos/coordinator
  '';
}
