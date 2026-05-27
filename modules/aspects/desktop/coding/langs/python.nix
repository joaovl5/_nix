_: {
  den.aspects.coding.homeManager = {pkgs, ...}: {
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
  den.aspects.coding.nixos = {
    programs.nix-ld.enable = true;
  };
}
