{
  hm = {
    pkgs,
    nixos_config,
    ...
  }: let
    cfg = nixos_config.my_nix;
  in {
    programs.vscode = {
      enable = true;
      package = pkgs.vscode.fhs;
      profiles.default.extensions = with pkgs.vscode-extensions; [
        esbenp.prettier-vscode
      ];
    };
  };
}
