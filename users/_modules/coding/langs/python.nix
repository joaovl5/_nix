{
  nx = _: {
    programs.nix-ld.enable = true;
  };
  hm = {pkgs, ...}: {
    programs.uv.enable = true;
    home.packages = with pkgs; [
      basedpyright
      ruff
    ];
  };
}
