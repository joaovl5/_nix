{
  hm = {
    pkgs,
    lib,
    ...
  }:
  # cfg = nixos_config.my.nix;
  # flake_path = cfg.flake_location;
  # here = assert (flake_path != null); "${flake_path}/users/_modules/yazi";
  # configSrc = config.lib.file.mkOutOfStoreSymlink "${here}/config";
  {
    programs.yazi = {
      enable = true;
      package = pkgs.yazi.override {_7zz = pkgs._7zz-rar;};
      settings = {
        yazi = lib.importTOML ./config/yazi.toml;
        preview = {
          image_quality = 90;
          max_width = 2048;
          max_height = 2048;
        };
      };
    };
    # home.file.".config/yazi" = {
    #   source = configSrc;
    #   recursive = true;
    #   force = true;
    # };
    #
    # home.packages = with pkgs; [
    #   yazi
    # ];
  };
}
