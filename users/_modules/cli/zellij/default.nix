{
  hm = {pkgs, ...}: let
    yazi_zellij_live_cwd = pkgs.writeShellApplication {
      name = "yazi-zellij-live-cwd";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.fish
      ];
      text = builtins.readFile ./yazi-zellij-live-cwd.sh;
    };

    yazi_zellij_toggle = pkgs.writeShellApplication {
      name = "yazi-zellij-toggle";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.jq
        pkgs.yazi
        pkgs.zellij
      ];
      text =
        builtins.replaceStrings
        ["@live_cwd_bin@"]
        ["${pkgs.lib.getExe yazi_zellij_live_cwd}"]
        (builtins.readFile ./yazi-zellij-toggle.sh);
    };
  in {
    hybrid-links.links.zellij = {
      from = ./config;
      to = "~/.config/zellij";
    };

    home.packages = [
      yazi_zellij_toggle
      yazi_zellij_live_cwd
    ];

    programs.zellij.enable = true;

    xdg.dataFile."zellij/plugins/zjstatus.wasm" = {
      source = "${pkgs.zjstatus}/bin/zjstatus.wasm";
    };
  };
}
