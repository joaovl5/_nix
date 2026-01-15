{
  hm = {
    pkgs,
    nixos_config,
    ...
  }: let
    cfg = nixos_config.mynix;
  in {
    programs.git = {
      enable = true;
      settings = {
        user.email = cfg.email;
        user.name = cfg.name;
      };
    };
    home.packages = with pkgs; [
      # lsp
      nixd
      nil
      # formatter
      alejandra
    ];
  };
}
