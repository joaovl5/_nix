{
  lib,
  pkgs,
  inputs,
  modulesPath,
  ...
}: {
  imports = [
    ./modules/pipewire.nix
    ./modules/grub.nix
    ./disko/testvm_btrfs.nix
    (modulesPath + "/profiles/qemu-guest.nix")
    inputs.nixpkgs.nixosModules.notDetected
  ];

  time.timeZone = "Americas/Sao_Paulo";

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  services.pipewire.enable = true;

  networking.useDHCP = lib.mkDefault true;
  networking.usePredictableInterfaceNames = true;

  boot.initrd.availableKernelModules = ["ahci" "xhci_pci" "virtio_pci" "virtio_scsi" "sr_mod" "virtio_blk"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-amd"];
  boot.extraModulePackages = [];
  boot.supportedFilesystems = {
    bcachefs = true;
  };
  boot.kernelPackages = pkgs.linuxPackages_latest;

  environment.defaultPackages = with pkgs; [
    openrgb
  ];

  # rgb
  hardware.i2c = {
    enable = true;
    group = "wheel";
  };

  services.udev.packages = with pkgs; [
    openrgb
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  nix.settings.max-jobs = lib.mkDefault 6;
}
