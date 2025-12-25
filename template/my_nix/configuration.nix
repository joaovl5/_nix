{
  lib,
  config,
  ...
}: let
  inherit (lib) mkMerge;
in {
  config = mkMerge [
    {
      my.hostname = "tyrant";
      my.username = "tyrant";

      my.hardware.modules = [
        ../hardware/testvm.nix
      ];
      my.disks.disko_module = ../hardware/disko/testvm_btrfs.nix;
      my.disks.disko_vars = {
        primary_device = "/dev/sda";
      };

      my.boot.ssh_port = 22251;
      my.ssh_port = 22250;
      # my.ssh_authorized_key = ./some-public-key.pub;

      soaps.defaultSopsFile = ./secrets.yaml;
      soaps.age = {
        sshKeyPaths = ["/boot/host_key"];
      };
      soaps.secrets."my-secrets/user/hashedPassword" = {
        neededForUsers = true;
      };
    }
  ];
}
