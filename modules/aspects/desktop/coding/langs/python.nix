_: {
  den.aspects.coding.homeManager = {pkgs, ...}: {
    programs.uv = {
      enable = true;
      settings = {
        preview = true;
        pip = {
          allow-empty-requirements = true;
          all-extras = true;
          strict = true;
          verify-hashes = true;
        };
      };
    };
    home.packages = with pkgs; [
      basedpyright
      pyrefly
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
    # needed for running python scripts et cetera
    programs.nix-ld.enable = true;
  };
}
