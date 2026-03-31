{
  lib,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.musnix.nixosModules.musnix
  ];

  musnix = {
    enable = true;
  };

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    audio.enable = true;
    raopOpenFirewall = true; # airplay
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    wireplumber.enable = true;
    jack.enable = true;
  };

  # services.pipewire.extraConfig.pipewire."92-low-latency" = {
  #   "context.properties" = {
  #     "default.clock.rate" = 48000;
  #     "default.clock.quantum" = 32;
  #     "default.clock.min-quantum" = 32;
  #     "default.clock.max-quantum" = 32;
  #   };
  # };

  environment.etc."openal/alsoft.conf".text = lib.mkDefault ''
    drivers=pulse,alsa
    htrf = true

    [pulse]
    allow-moves=true
  '';

  environment.defaultPackages = with pkgs; [
    libpulseaudio
    alsa-lib
  ];
}
