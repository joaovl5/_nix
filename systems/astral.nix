{ config, pkgs, lib, inputs, ... }:
let secrets = {
  hostName = "astral";
};
in
{
  networking = {
    hostName = lib.mkForce secrets.hostName;
  };

  users.mutableUsers = false;
  users.users.root.initialPassword = "12";

  security.polkit.enable = true;
  services.openssh.enable = true;
  programs.ssh.startAgent = true;

  virtualisation.docker.enable = true;
  virtualisation.libvirtd.enable = true;
  # todo put wm 

  documentation.man.generateCaches = true;
  services.dbus.packages = with pkgs; [ dconf ];

  environment.systemPackages = with pkgs; [
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
