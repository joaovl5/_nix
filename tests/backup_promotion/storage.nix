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
    settings.PasswordAuthentication = false;
  };

  users.users.backup-user = {
    isNormalUser = true;
    home = "/home/backup-user";
    createHome = true;
    openssh.authorizedKeys.keyFiles = ["${test_ssh_key}/id_ed25519.pub"];
  };

  # Provision the remote restic repo path here so the promotion test only
  # exercises the backup flow, not storage-side shell setup.
  system.activationScripts."backup-repos-dir" = lib.stringAfter ["users"] ''
    mkdir -p /var/lib/backups/repos/coordinator
    chown -R backup-user /var/lib/backups/repos
    chmod 755 /var/lib/backups /var/lib/backups/repos /var/lib/backups/repos/coordinator
  '';
}
