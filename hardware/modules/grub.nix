{ lib, ... }:
{
  boot.loader = {
    grub = {
      efiSupport = lib.mkDefault true;
      device = lib.mkDefault "nodev";
      configurationLimit = lib.mkDefault 60;
      theme = pkgs.nixos-grub2-theme;
    };
    efi.canTouchEfiVariables = lib.mkDefault true;
  };
}
