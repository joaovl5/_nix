{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  secrets = {
    hostName = "astral";
  };
in {
  networking = {
    hostName = lib.mkForce secrets.hostName;
  };

  users.mutableUsers = false;
  users.users.root = {
    initialPassword = "12";
    shell = pkgs.bash;
  };

  # scans network, detects hostnames
  services.avahi.enable = true;
  # automount media devices (cameras, phones, etc)
  gvfs.enable = true;
  # auth backend
  security.polkit.enable = true;
  # ssh daemon and agent
  services.openssh.enable = true;
  programs.ssh.startAgent = true;
  services.dbus.packages = with pkgs; [dconf];

  virtualisation.spiceUSBRedirection.enable = true;
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };
  virtualisation.libvirtd = {
    enable = true;
  };

  documentation.man.generateCaches = true;

  environment.systemPackages = with pkgs; [
    dconf
    curl
    git
    htop
    openal
    neovim
    pulseaudio
    wget
    fish
    inputs.zen-browser.packages.${pkgs.system}.default
  ];

  system.stateVersion = "26.05";
}
