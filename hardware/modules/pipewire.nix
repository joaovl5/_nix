{ config, lib, pkgs, ... }:
let
  cfg = config.services.pipewire;
in
lib.mkIf cfg.enable {
  security.rtkit.enable = lib.mkDefault true;

  services.pipewire = {
    pulse.enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
    alsa.support32Bit = lib.mkDefault true;
    wireplumber.enable = lib.mkDefault true;
  };

  environment.etc."openal/alsoft.conf".text = lib.mkDefault ''
    drivers=pulse,alsa
    htrf = true

    [pulse]
    allow-moves=true
  '';

  environment.defaultPackages = with pkgs; [
    # compatibility
    libpulseaudio
    alsa-lib
  ];

  # interface.hardware.audio = true;
}
