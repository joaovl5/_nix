{
  hm = {pkgs, ...}: {
    hybrid-links.links.zellij = {
      from = ./config;
      to = "~/.config/zellij";
    };

    programs.zellij = {
      enable = true;
    };

    xdg.dataFile."zellij/plugins/zjstatus.wasm" = {
      source = "${pkgs.zjstatus}/bin/zjstatus.wasm";
    };
  };
}
