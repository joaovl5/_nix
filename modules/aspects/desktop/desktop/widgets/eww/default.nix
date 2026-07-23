_: {
  den.aspects.desktop.homeManager = {
    config,
    lib,
    pkgs,
    ...
  }: let
    pkg = pkgs.eww;
    config_dir = "${config.xdg.configHome}/eww/bar";
    eww = "${pkg}/bin/eww --config ${config_dir}";
  in {
    hybrid-links.links.eww = {
      from = ./config;
      to = "~/.config/eww";
    };

    programs.eww = {
      enable = true;
      package = pkg;
      systemd.enable = true;
    };

    home.packages = [pkgs.jq];

    systemd.user.services.eww.Service = {
      ExecStart = lib.mkForce "${eww} daemon --no-daemonize";
      ExecStartPost = "${eww} open bar";
      ExecStop = lib.mkForce "${eww} kill";
      ExecReload = lib.mkForce "${eww} reload";
    };
  };
}
