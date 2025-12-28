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
    ./modules/pipewire.nix
    ./modules/grub.nix
    ./disko/testvm_btrfs.nix
    (modulesPath + "/profiles/qemu-guest.nix")
    inputs.nixpkgs.nixosModules.notDetected
  ];

  config.my_nix.hostname = "testvm";
  config.my_nix.username = "tester";
  config.my_nix.email = "vieiraleao2005+testvm@gmail.com";
  config.my_nix.name = "Tester";

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
