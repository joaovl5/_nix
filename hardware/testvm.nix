{ config, lib, pkgs, inputs, modulesPath, ... }:
let
  boot_disk = "/dev/vda";
  root_uuid = "0c748c2f-e173-47fb-a059-e8a26f5d7adc";
  swap_uuid = "ad065f12-cb45-44a9-b69a-e39effadc0dd";
in
{
  imports =
    [
      ./modules/pipewire.nix
      ./modules/grub.nix
      (modulesPath + "/profiles/qemu-guest.nix")
      inputs.nixpkgs.nixosModules.notDetected
    ];

  time.timeZone = "Americas/Sao_Paulo";

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  services.pipewire.enable = true;

  networking.useDHCP = lib.mkDefault true;
  networking.usePredictableInterfaceNames = true;

  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "virtio_scsi" "sr_mod" "virtio_blk" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];
  boot.supportedFilesystems = {
    bcachefs = true;
  };
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.loader.grub.enable = false;
  boot.loader.systemd-boot = {
    enable = true;
    # we use Git for version control, so we don't need to keep too many generations.
    configurationLimit = lib.mkDefault 10;
    # pick the highest resolution for systemd-boot's console.
    consoleMode = lib.mkDefault "max";
  };

  boot.loader.timeout = lib.mkDefault 8; # wait for x seconds to select the boot entry

  fileSystems."/" =
    {
      device = "/dev/vda1:/dev/vdb1";
      # device = "UUID=${root_uuid}";
      fsType = "bcachefs";
    };

  swapDevices =
    [{ device = "/dev/disk/by-uuid/${swap_uuid}"; }];

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
