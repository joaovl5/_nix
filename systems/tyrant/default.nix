_: {
  imports = [
    ../_bootstrap/server.nix
  ];

  my = {
    server.enable = true;
    host.title_file = ./assets/title.txt;
    host.password.sops_key = "server";

    "unit.octodns" = {
      enable = true;
    };

    "unit.traefik" = {
      enable = true;
    };

    "unit.pihole" = {
      enable = true;
      dns = {
        interface = "enp3s0f1";
      };
    };

    "unit.litellm" = {
      enable = true;
    };

    "unit.nixarr" = {
      enable = true;
    };

    "unit.soularr" = {
      enable = true;
    };

    "unit.fxsync" = {
      enable = true;
    };
  };
}
