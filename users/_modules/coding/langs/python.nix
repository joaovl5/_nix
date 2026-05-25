{
  nx = _: {
    programs.nix-ld.enable = true;
  };
  hm = {pkgs, ...}: {
    programs.uv.enable = true;
    home.packages = with pkgs; [
      basedpyright
      ruff
      ty
      (python3.withPackages (
        ps:
          with ps; [
            debugpy
          ]
      ))
    ];
  };
}
