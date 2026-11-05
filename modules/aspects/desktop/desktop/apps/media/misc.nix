_: {
  den.aspects.desktop.homeManager = {pkgs, ...}: {
    home.packages = with pkgs; [
      ffmpeg-full
      yt-dlp
      mpv
      vlc
      # krita
      # inkscape
    ];

    programs.freetube = {
      enable = true;
    };
  };
}
