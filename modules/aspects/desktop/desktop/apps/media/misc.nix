_: {
  den.aspects.desktop.nixos = _: {
    programs.obs-studio = {
      enableVirtualCamera = true;
    };
  };
  den.aspects.desktop.homeManager = {pkgs, ...}: {
    home.packages = with pkgs; [
      ffmpeg-full
      yt-dlp
      mpv
      vlc
      # krita
      # inkscape
    ];
    programs.obs-studio = {
      enable = true;
      plugins = with pkgs.obs-studio-plugins; [
        wlrobs
        waveform
        obs-wayland-hotkeys
        obs-vkcapture
        obs-transition-table
      ];
    };

    programs.freetube = {
      enable = true;
    };
  };
}
