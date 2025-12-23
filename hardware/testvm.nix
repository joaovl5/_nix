{
  lib,
  pkgs,
  inputs,
  modulesPath,
  disk_config
  ...
}: {
  imports = [
    ./modules/pipewire.nix
    ./modules/grub.nix
    disk_config
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
  boot.kernelModules = ["kvm-amd"];
  boot.kernelPackages = pkgs.linuxPackages_latest;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  nix.settings.max-jobs = lib.mkDefault 6;
}
