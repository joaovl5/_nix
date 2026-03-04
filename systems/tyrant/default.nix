{mylib, ...}: {
  imports = [
    ../_bootstrap/server.nix
    (mylib.hosts.host_config "tyrant")
  ];

  my = {
    server.enable = true;
    host.title_file = ./assets/title.txt;
    host.password.sops_key = "server";
  };
}
