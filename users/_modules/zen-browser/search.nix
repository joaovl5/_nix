{pkgs, ...}: let
  engine = {
    name,
    url,
    icon,
    alias,
  }: {
    inherit name;
    inherit icon;
    definedAliases = ["@${alias}"];
    urls = [
      {
        template = url;
        params = [
          {
            name = "query";
            value = "x";
          }
        ];
      }
    ];
  };
in {
  force = true;
  default = "ddg";
  engines = {
    mynixos = engine {
      name = "My NixOS";
      url = "https://mynixos.com/search?q={x}";
      icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
      alias = "nx";
    };
    noogle = engine {
      name = "Noogle";
      url = "https://noogle.dev/q?term={x}";
      icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
      alias = "ng";
    };
  };
}
