_: {
  imports = [
    ../_bootstrap/server.nix
  ];

  my = {
    server.enable = true;
    host.title_file = ./assets/title.txt;
    host.password.sops_key = "server";
  };
}
