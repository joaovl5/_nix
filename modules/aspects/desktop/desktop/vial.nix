{
  den.aspects.desktop.nixos = {inputs, ...}: let
    inherit (inputs) entropy;
  in {
    imports = [entropy.nixosModules.default];
    programs.entropy = {
      enable = true;
      ibus.enable = true;
    };
    i18n.inputMethod = {
      enable = true;
      type = "ibus";
    };
  };

  # nixpkgs' ibus autostart hardcodes `ibus-daemon --daemonize --xim`
  # (nixos/modules/i18n/input-method/ibus.nix) and exposes no option to change it.
  # The XIM server is what breaks Vim mode in Electron apps on XWayland: keys
  # arrive as IME commits, so Codemirror-vim never sees keydowns.
  # A same-named file in $XDG_CONFIG_HOME/autostart outranks every
  # XDG_CONFIG_DIRS entry, so this replaces the system
  # /run/current-system/sw/etc/xdg/autostart/ibus-daemon.desktop.
  # The panel can be turned off with `--panel=disable`.
  den.aspects.desktop.homeManager = {nixos_config, ...}: {
    xdg.configFile."autostart/ibus-daemon.desktop".text = ''
      [Desktop Entry]
      Name=IBus
      Type=Application
      Exec=${nixos_config.i18n.inputMethod.package}/bin/ibus-daemon --daemonize
      Comment=IBus without the XIM server
      NotShowIn=GNOME;KDE;
    '';
  };
}
