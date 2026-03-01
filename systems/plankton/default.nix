/*
  ▜     ▌ ▗
▛▌▐ ▀▌▛▌▙▘▜▘▛▌▛▌
▙▌▐▖█▌▌▌▛▖▐▖▙▌▌▌
▌

Plankton is meant to be a slimmer system for containers and other
applications requiring lightweight resource usage
*/
{
  config,
  lib,
  mylib,
  ...
}: let
  cfg = config.my.nix;
  s = (mylib.use config).secrets;
in {
  imports = [
    ../_modules/console
    ../_modules/security
    ../_modules/services/ntp.nix
    ../_modules/console
    {my_system.title = lib.mkDefault (lib.readFile ./assets/title.txt);}
  ];

  networking = {
    hostName = lib.mkForce cfg.hostname;
  };

  users.mutableUsers = false;
  users.users.root = {
    hashedPassword = lib.mkForce null;
    hashedPasswordFile = s.secret_path "password_hash";
  };

  services.openssh.enable = true;

  programs = {
    neovim.enable = true;
    neovim.defaultEditor = true;
    tmux.enable = true;
    git.enable = true;
  };

  system.stateVersion = "25.11";
}
