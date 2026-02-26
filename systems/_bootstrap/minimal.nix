/*
base system for other minimal systems to use (iso/netboot)
this is not meant to work by itself
*/
{
  pkgs,
  lib,
  inputs,
  system,
  ...
} @ args: let
  public_data = import ../../_modules/public.nix args;

  ssh_port = 2222;
  ssh_authorized_keys = [
    public_data.ssh_key
  ];

  user = "nixos";
in {
  imports = [
    ../plankton
    ../_modules/security
    ../_modules/services/ntp.nix
    ../_modules/console
  ];

  my.nix = {
    username = user;
    email = "vieiraleao2005+bootstrap@gmail.com";
    name = "João Pedro";
  };

  # enable SSH in the boot process
  systemd.services.sshd.wantedBy = lib.mkForce ["multi-user.target"];
  programs = {
    fish = {
      enable = true;
    };
  };

  services.openssh = {
    ports = lib.mkForce [ssh_port];
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  users.users."${user}" = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = ssh_authorized_keys;
  };

  environment.systemPackages = with pkgs; [
    neovim
    tmux
    btop
    glances

    # installer deps
    rsync
    git
    inputs.disko.packages.${system}.default
    nixos-facter
  ];
}
