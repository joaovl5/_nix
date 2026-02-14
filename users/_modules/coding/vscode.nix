{
  hm = {pkgs, ...}: {
    programs.vscode = {
      enable = true;
      package = pkgs.vscode.fhs;
      profiles.default.extensions = with pkgs.vscode-extensions; [
        esbenp.prettier-vscode
      ];
    };
  };
}
