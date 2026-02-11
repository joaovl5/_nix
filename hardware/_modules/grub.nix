{
  lib,
  pkgs,
  ...
}: {
  boot.loader = {
    grub = {
      enable = lib.mkDefault true;
      device = lib.mkDefault "nodev";
      efiSupport = lib.mkDefault true;
      configurationLimit = lib.mkDefault 60;
      theme = lib.mkDefault pkgs.nixos-grub2-theme;
      enableCryptodisk = lib.mkDefault true;
    };
    efi.canTouchEfiVariables = lib.mkDefault true;
  };
}
