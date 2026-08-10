_: {
  den.aspects.desktop.homeManager = {
    config,
    lib,
    nixos_config,
    pkgs,
    ...
  }: let
    pkg = pkgs.eww;
    config_dir = "${config.xdg.configHome}/eww/bar";
    eww = "${pkg}/bin/eww --config ${config_dir}";
    calendar_secret = nixos_config.sops.secrets.lav_shell.path;
  in {
    hybrid-links.links = {
      eww_bar = {
        from = ./config/bar;
        to = "~/.config/eww/bar";
      };
      eww_config = {
        from = ./config/lav-shell.toml;
        to = "~/.config/eww/lav-shell.toml";
        recursive = false;
      };
      eww_project = {
        from = ./config/lav-shell;
        to = "~/.config/eww/lav-shell";
      };
    };

    home.file.".config/eww/lav-shell.secrets" = {
      source = config.lib.file.mkOutOfStoreSymlink calendar_secret;
      force = true;
    };

    home.activation.migrate_eww_config_link = lib.hm.dag.entryBetween ["linkGeneration"] ["writeBoundary"] ''
      eww_config=${lib.escapeShellArg "${config.xdg.configHome}/eww"}
      if [[ -L "$eww_config" ]]; then
        run rm $VERBOSE_ARG -- "$eww_config"
      fi
    '';

    programs.eww = {
      enable = true;
      package = pkg;
      systemd.enable = true;
    };

    home.packages = [pkgs.jq pkgs.uv];

    systemd.user.services.eww.Service = {
      Environment = [
        "PYTHONPYCACHEPREFIX=${config.xdg.cacheHome}/lav-shell/pycache"
        "UV_PROJECT_ENVIRONMENT=${config.xdg.cacheHome}/lav-shell/.venv"
        "UV_PYTHON=${pkgs.python314}/bin/python"
        "UV_PYTHON_DOWNLOADS=never"
      ];
      ExecStart = lib.mkForce "${eww} daemon --no-daemonize";
      ExecStartPost = [
        "${eww} open bar"
        "${eww} open calendar-bar"
      ];
      ExecStop = lib.mkForce "${eww} kill";
      ExecReload = lib.mkForce "${eww} reload";
    };
  };

  den.aspects.desktop.nixos = {
    config,
    mylib,
    ...
  }: let
    my = mylib.use config;
    s = my.secrets;
  in {
    sops.secrets.lav_shell = s.mk_secret_user "${s.dir}/lav-shell.yaml" "lav-shell" {};
  };
}
