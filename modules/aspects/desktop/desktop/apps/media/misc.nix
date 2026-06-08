_: {
  den.aspects.desktop.homeManager = {pkgs, ...}: {
    home.packages = with pkgs; [
      ffmpeg-full
      yt-dlp
      mpv
      vlc
    ];

    programs.freetube = {
      enable = true;
    };
  };
}
