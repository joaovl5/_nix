{
  hm = {pkgs, ...}: {
    programs.uv.enable = true;
    home.packages = with pkgs; [
      basedpyright
      ruff
    ];
  };
}
