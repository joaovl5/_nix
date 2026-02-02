/*
  ▜     ▌ ▗
▛▌▐ ▀▌▛▌▙▘▜▘▛▌▛▌
▙▌▐▖█▌▌▌▛▖▐▖▙▌▌▌
▌

Plankton is meant to be a slimmer system for containers and other
applications requiring lightweight resource usage
*/
{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.my_nix;
in {
  imports = [
    ../_modules/console
    ../_modules/security
    ../_modules/services/ntp.nix
    ../_modules/console
    {my_system.title = lib.readFile ./assets/title.txt;}
  ];

  networking = {
    hostName = lib.mkForce cfg.hostname;
  };

  users.mutableUsers = false;
  users.users.root = {
    hashedPasswordFile = config.sops.secrets.password_hash.path;
  };

  users.defaultUserShell = lib.mkDefault pkgs.dash;
  users.users.root.shell = lib.mkDefault pkgs.dash;

  services.openssh.enable = true;

  programs = {
    neovim.enable = true;
    neovim.defaultEditor = true;
    tmux.enable = true;
    git.enable = true;
  };

  system.stateVersion = "25.11";
}
