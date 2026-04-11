/*
base system for desktop systems to use
this is not meant to work by itself
*/
{
  config,
  mylib,
  pkgs,
  ...
}: let
  my = mylib.use config;
  o = my.options;
in
  o.module "desktop" (with o; {
    enable = toggle "Enable desktop presets" false;
  }) {
    imports = _: [
      ./host.nix
      ../_modules/services/login.nix
      ../_modules/services/audio.nix
      ../_modules/storage/client.nix
    ];
  } (opts: (o.when opts.enable (o.merge [
    {
      my.host = {
        enable = true;
      };

      boot.kernelPackages = o.def pkgs.linuxKernel.packages.linux_zen;

      services = {
        gvfs.enable = o.def true; # automount media devices
        flatpak.enable = o.def true;
        xserver.enable = o.def false;
      };

      services.dbus = {
        enable = true;
        implementation = o.force "dbus";
        packages = with pkgs; [dconf];
      };

      programs = {
        xwayland.enable = o.def true; # x11 compat
        ssh.startAgent = o.def true;
        dconf.enable = o.def true; # dependency of many things
      };

      documentation = {
        enable = o.def true;
        nixos = {
          enable = o.def true;
          # not using this and it's causing issues
          # optnix also does not need this
          includeAllModules = false;
        };
        doc = {enable = o.def true;};
        dev = {enable = o.def true;};
        man = {
          enable = o.def true;
          generateCaches = o.def true;
        };
      };

      environment = {
        enableAllTerminfo = o.def true;
        systemPackages = with pkgs; [
          ### system monitoring/inspection
          pciutils
          nvtopPackages.full

          ### decoration
          cbonsai

          ### etc
          tealdeer # tldr alternative
          pandoc
          typst
          rm-improved # rm alt.

          #### other etc
          gcc
          gnumake
          lldb
          lshw
        ];
      };
    }
  ])))
