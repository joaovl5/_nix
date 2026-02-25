{
  hm = {
    config,
    nixos_config,
    ...
  }: let
    cfg = nixos_config.my.nix;
    flake_path = cfg.flake_location;
    here = assert (flake_path != null); "${flake_path}/users/_modules/cli/intellishell";
    data_src = config.lib.file.mkOutOfStoreSymlink "${here}/data";
  in {
    xdg.dataFile."intellishell_data" = {
      source = data_src;
      recursive = true;
      force = true;
    };
    programs.intelli-shell = {
      enable = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;
      settings = {
        data_dir = "${config.xdg.dataHome}/intellishell_data";
        theme = {
          accent = "yellow";
        };
      };
    };
  };
}
