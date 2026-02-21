{
  hm = {
    nixos_config,
    lib,
    pkgs,
    ...
  }: let
    inherit (lib) mkMerge mkIf;
    cfg = nixos_config.my.nix;
  in {
    programs = {
      # better nix cli
      nh = mkMerge [
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
      nix-index = {
        enable = true;
      };

      # handling direnv w/ nix integrations
      direnv = {
        enable = true;
        nix-direnv.enable = true;
      };
    };

    # faster direnv
    services.lorri = {
      enable = true;
    };

    home.packages = with pkgs; [
      # runs software without installing
      comma
      # search packages
      rippkgs
      # edit flake inputs
      flake-edit
    ];
  };
}
