{
  hm = {pkgs, ...}: let
    node_pkg = pkgs.nodejs;
  in {
    programs.npm = {
      enable = true;
      package = node_pkg;
      settings = {
        color = true;
        maxsockets = 30;
        prefer-offline = true;
        fetch-retries = 3;
        fetch-retry-mintimeout = 15000; # 15s
        fetch-retry-maxtimeout = 90000; # 1m30s
      };
    };
    programs.bun = {
      enable = true;
    };
    home.packages = [
      node_pkg
    ];
  };
}
