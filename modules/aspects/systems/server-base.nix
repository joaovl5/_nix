{den, ...}: {
  den.aspects.system-server-base = {
    includes = [den.aspects.system-host-base];

    nixos = {
      config,
      mylib,
      ...
    }: let
      my = mylib.use config;
      o = my.options;
    in
      o.module "server" (with o; {
        enable = toggle "Enable server presets" false;
      }) {} (opts: (o.when opts.enable (o.merge [
        {
          my.host = {
            enable = true;
            disable_privileged_ports = true;
          };

          # Keep servers on classic dbus for live-switch deploys; migrating to dbus-broker requires boot + reboot.
          services.dbus = {
            enable = true;
            implementation = o.force "dbus";
          };
        }
      ])));
  };
}
