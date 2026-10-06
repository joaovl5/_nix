_: {
  den.aspects.desktop.homeManager = {pkgs, ...}: {
    home.packages = with pkgs; [
      font-manager

      # monospace
      # keep-sorted start
      anonymous-pro-fonts
      cozette
      drafting-mono
      kode-mono
      maple-mono.NF
      nerd-fonts._0xproto
      nerd-fonts.bigblue-terminal
      nerd-fonts.departure-mono
      nerd-fonts.iosevka
      nerd-fonts.mononoki
      nerd-fonts.recursive-mono
      vt323
      # keep-sorted end

      # sans-serif
      inter-nerdfont
    ];
  };
}
