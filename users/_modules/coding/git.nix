{
  hm = {
    pkgs,
    nixos_config,
    ...
  }: let
    cfg = nixos_config.my_nix;
  in {
    # TODO add merging stuff
    programs.git = {
      enable = true;
      settings = {
        user.email = cfg.email;
        user.name = cfg.name;
      };
    };
  };
}
