{
  hm = {
    nixos_config,
    pkgs,
    ...
  }: let
    cfg = nixos_config.my.nix;
  in {
    # TODO: ^1 add merging stuff
    programs.git = {
      enable = true;
      settings = {
        user.email = cfg.email;
        user.name = cfg.name;
      };
    };

    home.packages = with pkgs; [
      prek
    ];
  };
}
