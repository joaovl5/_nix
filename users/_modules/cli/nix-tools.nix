{
  hm = {
    nixos_config,
    lib,
    ...
  }: let
    inherit (lib) mkMerge mkIf;
    cfg = nixos_config.my.nix;
  in {
    # better nix cli
    programs.nh = mkMerge [
      {
        enable = true;
        clean.enable = true;
        clean.extraArgs = "--keep 5 --keep-since 5d";
      }
      (mkIf (cfg.flake_location != null) {
        flake = cfg.flake_location;
      })
    ];

    # indexing of nixpkgs
    programs.nix-index = {
      enable = true;
    };

    # handling direnv w/ nix integrations
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
