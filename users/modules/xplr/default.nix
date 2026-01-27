{
  hm = {
    pkgs,
    config,
    nixos_config,
    ...
  }: let
    cfg = nixos_config.my_nix;
    flake_path = cfg.flake_location;
    here = assert (flake_path != null); "${flake_path}/users/modules/xplr";
    configSrc = config.lib.file.mkOutOfStoreSymlink "${here}/settings";
  in {
    xdg.configFile."xplr" = {
      source = configSrc;
      recursive = true;
      force = true;
    };

    home.packages = with pkgs; [
      xplr
    ];
  };
}
