{
  lib,
  config,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.my.nix;
  disko_cfg = import ../_disko/server_1.nix {primary_device = "/dev/sda";};
in {
  imports = [
    ../_modules/grub.nix
    disko_cfg
    inputs.nixpkgs.nixosModules.notDetected
  ];

  my = {
    nix = {
      hostname = "tyrant";
      username = "tyrant";
      email = "vieiraleao2005+tyrant@gmail.com";
      name = "Tyrant";
      is_server = true;
    };
  };

  time.timeZone = cfg.timezone;

  networking.useDHCP = lib.mkDefault true;
  networking.usePredictableInterfaceNames = true;

  boot = {
    initrd.availableKernelModules = ["uhci_hcd" "ehci_pci" "ata_piix" "hpsa" "usb_storage" "usbhid" "sd_mod" "sr_mod"];
    initrd.kernelModules = ["dm-snapshot"];
    kernelModules = ["kvm-intel"];
    kernelPackages = pkgs.linuxPackages_latest;
    loader.grub.efiSupport = false;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  nix.settings.max-jobs = lib.mkDefault 6;
}
