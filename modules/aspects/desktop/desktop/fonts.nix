_: {
  den.aspects.desktop.nixos = {pkgs, ...}: {
    environment.systemPackages = [pkgs.font-manager];
    fonts = {
      enableDefaultPackages = true;
      fontDir.enable = true;
      packages = with pkgs; [
        #======================== monospaces ========================
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

        #======================== sans-serif ========================
        # keep-sorted start
        inter-nerdfont
        # keep-sorted end

        #========================== serifs ==========================
        # keep-sorted start
        # keep-sorted end
      ];
    };
  };
}
