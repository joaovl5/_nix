{
  hm = {
    config,
    pkgs,
    nixos_config,
    ...
  }: let
    cfg = nixos_config.my.nix;
    flake_path = cfg.flake_location;
    here = assert (flake_path != null); "${flake_path}/users/_modules/cli/zellij";
    configSrc = config.lib.file.mkOutOfStoreSymlink "${here}/config";
  in {
    programs.zellij = {
      enable = true;
    };

    xdg.dataFile."zellij/plugins/zjstatus.wasm" = {
      source = "${pkgs.zjstatus}/bin/zjstatus.wasm";
    };

    xdg.configFile."zellij" = {
      source = configSrc;
      recursive = true;
      force = true;
    };
  };
}
