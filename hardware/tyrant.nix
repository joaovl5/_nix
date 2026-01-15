{
  lib,
  config,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.my_nix;
  disko_cfg = import ./disko/server_1.nix {primary_device = "/dev/sda";};
in {
  imports = [
    ./modules/grub.nix
    disko_cfg
    inputs.nixpkgs.nixosModules.notDetected
  ];

  my_nix.hostname = "tyrant";
  my_nix.username = "tyrant";
  my_nix.email = "vieiraleao2005+tyrant@gmail.com";
  my_nix.name = "Tyrant";
  my_nix.is_server = true;

  time.timeZone = cfg.timezone;

  networking.useDHCP = lib.mkDefault true;
  networking.usePredictableInterfaceNames = true;

  boot.initrd.availableKernelModules = ["uhci_hcd" "ehci_pci" "ata_piix" "hpsa" "usb_storage" "usbhid" "sd_mod" "sr_mod"];
  boot.initrd.kernelModules = ["dm-snapshot"];
  boot.kernelModules = ["kvm-intel"];
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.loader.grub.efiSupport = false;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  nix.settings.max-jobs = lib.mkDefault 6;
}
