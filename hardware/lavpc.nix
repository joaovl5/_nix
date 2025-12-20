{
  lib,
  pkgs,
  modulesPath,
  inputs,
  ...
}: {
  imports =
    inputs.self.moduleSets.hardware
    ++ [
      (modulesPath + "/profiles/qemu-guest.nix")
      inputs.nixpkgs.nixosModules.notDetected
    ];

  time.timeZone = "Americas/Sao_Paulo";

  boot.initrd.availableKernelModules = ["ahci" "xhci_pci" "virtio_pci" "virtio_scsi" "sr_mod" "virtio_blk"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-amd"];
  boot.extraModulePackages = [];

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  services.pipewire.enable = true;

  networking.useDHCP = lib.mkDefault true;
  networking.usePredictableInterfaceNames = true;

  # rgb
  hardware.i2c = {
    enable = true;
    group = "wheel";
  };

  services.udev.packages = with pkgs; [
    openrgb
  ];

  environment.defaultPackages = with pkgs; [
    openrgb
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  nix.settings.max-jobs = lib.mkDefault 6;
}
