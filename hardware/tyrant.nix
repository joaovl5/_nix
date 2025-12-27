{
  lib,
  pkgs,
  inputs,
  modulesPath,
  ...
}: {
  imports = [
    ./modules/grub.nix
    ./disko/server_1.nix
    inputs.nixpkgs.nixosModules.notDetected
  ];

  time.timeZone = "Americas/Sao_Paulo";

  networking.useDHCP = lib.mkDefault true;
  networking.usePredictableInterfaceNames = true;

  boot.initrd.availableKernelModules = ["uhci_hcd" "ehci_pci" "ata_piix" "hpsa" "usb_storage" "usbhid" "sd_mod" "sr_mod"];
  boot.initrd.kernelModules = ["dm-snapshot"];
  boot.kernelModules = ["kvm-intel"];
  boot.kernelPackages = pkgs.linuxPackages_hardened;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  nix.settings.max-jobs = lib.mkDefault 6;
}
