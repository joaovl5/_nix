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
      theme = lib.mkDefault pkgs.sleek-grub-theme;
      # enableCryptodisk = lib.mkDefault false;
    };
    efi.canTouchEfiVariables = lib.mkDefault true;
  };
}
