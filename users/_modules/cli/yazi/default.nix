{
  hm = {pkgs, ...}: {
    hybrid-links.links.yazi = {
      from = ./config;
      to = "~/.config/yazi";
    };

    programs.yazi = {
      enable = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;
      shellWrapperName = "y";
      package = pkgs.yazi.override {_7zz = pkgs._7zz-rar;};
    };
  };
}
