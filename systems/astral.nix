{ config, pkgs, lib, ... }:
let secrets = {
  hostName = "astral";
};
in
{
  assertions =
    let
      hw = config.interface.hardware;
    in
    [
      {
        assertion = hw.networking;
        message = "This config requires networking!";
      }
      {
        assertion = hw.gui;
        message = "This config requires graphical hardware!";
      }
    ];

  networking = {
    hostName = lib.mkForce secrets.hostName;
  };

  users.mutableUsers = false;
  users.users.root.initialPassword = "12";

  security.polkit.enable = true;
  services.openssh.enable = true;
  programs.ssh.startAgent = true;

  virtualisation.docker.enable = true;
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      ovmf.enable = true;
    };
  };

  # todo put wm 

  documentation.man.generateCaches = true;
  services.dbus.packages = with pkgs; [ dconf ];

  environment.systemPackages = with pkgs; [
    curl
    git
    htop
    lynx
    openal
    neovim-nightly
    pulseaudio
    tinycc
    transcrypt
    wget
  ];
}
