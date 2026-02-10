{
  lib,
  config,
  pkgs,
  inputs,
  modulesPath,
  ...
}: let
  cfg = config.my_nix;
in {
  imports = [
    ../_modules/grub.nix
    ./disko.nix
    (modulesPath + "/profiles/qemu-guest.nix")
    inputs.nixpkgs.nixosModules.notDetected
  ];

  my_nix.hostname = "tyrantvm";
  my_nix.username = "tyrant";
  my_nix.email = "vieiraleao2005+testservervm@gmail.com";
  my_nix.name = "Tyrant";

  time.timeZone = cfg.timezone;

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  services.pipewire.enable = true;

  networking.useDHCP = lib.mkDefault true;
  networking.usePredictableInterfaceNames = true;

  boot.initrd.availableKernelModules = ["ahci" "xhci_pci" "virtio_pci" "virtio_scsi" "sr_mod" "virtio_blk"];
  boot.kernelModules = ["kvm-amd"];
  boot.kernelPackages = pkgs.linuxPackages_latest;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  nix.settings.max-jobs = lib.mkDefault 6;
}
