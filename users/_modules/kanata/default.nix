{
  hm = {
    config,
    nixos_config,
    ...
  }: let
    cfg = nixos_config.my.nix;
    flake_path = cfg.flake_location;
    here = assert (flake_path != null); "${flake_path}/users/_modules/kanata";
    configSrc = config.lib.file.mkOutOfStoreSymlink "${here}/config";
  in {
    xdg.configFile."kanata" = {
      source = configSrc;
      recursive = true;
      force = true;
    };
  };

  nx = {
    pkgs,
    lib,
    ...
  }: let
    keyboard_name = "internalKeyboard";
  in {
    boot.kernelModules = ["uinput"];
    hardware.uinput.enable = true;

    services.udev.extraRules = ''
      KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"
    '';

    users.groups.uinput = {
      gid = lib.mkForce 989;
    };

    systemd.user.services."kanata-${keyboard_name}" = {
      enable = true;
      description = "Kanata keyboard remapper for ${keyboard_name}";
      wantedBy = ["default.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.kanata}/bin/kanata --cfg %h/.config/kanata/config.kbd";
        Restart = "on-failure";
        RestartSec = 3;
      };
    };
  };
}
