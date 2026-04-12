{lib, ...}: let
  o = import ../../_lib/options {
    inherit lib;
    config = {
      my = {};
    };
  };
in
  o.meta_module "kanata" {
    options = with o; {
      enable = toggle "Kanata keyboard remapping" false;
      keyboard_name = opt "Keyboard name used in the Kanata systemd user unit." t.str "internalKeyboard";
    };

    hm = {
      lib,
      opts,
      ...
    }: {
      config = lib.mkIf opts.enable {
        hybrid-links.links.kanata = {
          from = ./config;
          to = "~/.config/kanata";
        };
      };
    };

    nx = {
      lib,
      pkgs,
      opts,
      ...
    }: {
      config = lib.mkIf opts.enable {
        boot.kernelModules = ["uinput"];
        hardware.uinput.enable = true;

        services.udev.extraRules = ''
          KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"
        '';

        users.groups.uinput = {
          gid = lib.mkForce 989;
        };

        systemd.user.services."kanata-${opts.keyboard_name}" = {
          enable = true;
          description = "Kanata keyboard remapper for ${opts.keyboard_name}";
          wantedBy = ["default.target"];
          serviceConfig = {
            Type = "simple";
            ExecStart = "${pkgs.kanata}/bin/kanata --cfg %h/.config/kanata/config.kbd";
            Restart = "on-failure";
            RestartSec = 3;
          };
        };
      };
    };
  }
