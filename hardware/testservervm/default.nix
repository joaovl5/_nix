{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.my.nix;
in {
  imports = [
    ../_modules/grub.nix
    ../_modules/facter.nix
    ../_modules/luks.nix
    ./disko.nix
  ];

  my.nix.hostname = "testservervm";
  my.nix.username = "tyrant";
  my.nix.email = "vieiraleao2005+testservervm@gmail.com";
  my.nix.name = "Tyrant";

  my.facter.enable = true;
  my.luks.ssh.enable = true;
  my.luks.ssh.use_dhcp = true;

  time.timeZone = cfg.timezone;

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  services.pipewire.enable = true;

  networking.useDHCP = lib.mkDefault true;
  networking.usePredictableInterfaceNames = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.loader.grub.efiSupport = false;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  nix.settings.max-jobs = lib.mkDefault 6;
}
