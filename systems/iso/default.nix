{
  pkgs,
  lib,
  inputs,
  modulesPath,
  system,
  ...
} @ args: let
  public_data = import ../../_modules/public.nix args;

  ssh_port = 2222;
  ssh_authorized_keys = [
    # all host keys should go here
    # - git_ro_key
    # - servers/etc
    public_data.ssh_key
  ];

  user = "nixos";
in {
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
    ../plankton
    ../_modules/security
    ../_modules/services/ntp.nix
    ../_modules/console
    {my_system.title = lib.readFile ./assets/title.txt;}
  ];

  my_nix = {
    hostname = "my_iso";
    username = user;
    email = "vieiraleao2005+my_iso@gmail.com";
    name = "João Pedro";
  };

  # faster build time
  isoImage.squashfsCompression = "gzip -Xcompression-level 1";

  # enable SSH in the boot process
  systemd.services.sshd.wantedBy = lib.mkForce ["multi-user.target"];

  programs = {
    fish = {
      enable = true;
    };
  };

  services.openssh = {
    ports = lib.mkForce [ssh_port];
    passwordAuthentication = false;
    permitRootLogin = "no";
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
