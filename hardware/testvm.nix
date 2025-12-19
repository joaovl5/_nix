{ config, lib, pkgs, inputs, modulesPath, ... }:

{
  # imports =
  #   inputs.self.moduleSets.hardware ++
  #   [
  #     inputs.nixpkgs.nixosModules.notDetected
  #   ];

  time.timeZone = "Americas/Sao_Paulo";

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  services.pipewire.enable = true;

  networking.useDHCP = lib.mkDefault true;
  networking.usePredictableInterfaceNames = true;
  config = {
    interface.hardware.networking = true;
    interface.hardware.gui = true;

    boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "virtio_scsi" "sr_mod" "virtio_blk" ];
    boot.initrd.kernelModules = [ ];
    boot.kernelModules = [ "kvm-amd" ];
    boot.extraModulePackages = [ ];
    boot.kernelPackages = pkgs.linuxPackages_latest;

    fileSystems."/" =
      {
        device = "UUID=90ecc4f4-65ca-47df-b362-5184cda952d0";
        fsType = "bcachefs";
      };

    swapDevices =
      [{ device = "/dev/disk/by-uuid/14520cb5-f22d-4354-83b3-44c10f2e0574"; }];

    environment.defaultPackages = with pkgs; [
      openrgb
    ];
  };

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
