{
  hm = {pkgs, ...}: {
    home.packages = with pkgs; [
      font-manager

      # monospace
      nerd-fonts.iosevka
      nerd-fonts._0xproto
      nerd-fonts.departure-mono
      nerd-fonts.recursive-mono
      nerd-fonts.bigblue-terminal
      cozette
      kode-mono
      vt323
      maple-mono.NF
      anonymous-pro-fonts

      # sans-serif
      inter-nerdfont
    ];
  };
}
