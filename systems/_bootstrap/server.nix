/*
base system for server systems to use
this is not meant to work by itself
*/
{
  config,
  mylib,
  ...
}: let
  my = mylib.use config;
  o = my.options;
in
  o.module "server" (with o; {
    enable = toggle "Enable server presets" false;
  }) {
    imports = _: [
      ./host.nix
    ];
  } (opts: (o.when opts.enable (o.merge [
    {
      my.host = {
        enable = true;
        disable_privileged_ports = true;
      };
    }
  ])))
