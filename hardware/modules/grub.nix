{ lib, pkgs, ... }:
{
  boot.loader = {
    grub = {
      enable = true;
      efiSupport = lib.mkDefault true;
      configurationLimit = lib.mkDefault 60;
      theme = pkgs.nixos-grub2-theme;
    };
    efi.canTouchEfiVariables = lib.mkDefault true;
  };
}
