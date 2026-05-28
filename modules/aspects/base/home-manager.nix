{lav, ...}: {
  den.aspects.base-home-manager.meta.collisionPolicy = "class-wins";
  den.aspects.base-home-manager.nixos = {
    inputs,
    lib,
    pkgs,
    config,
    options,
    system,
    mylib,
    globals,
    ...
  }: {
    imports = with inputs; [
      hm.nixosModules.home-manager
    ];

    home-manager = {
      useGlobalPkgs = lib.mkDefault true;
      useUserPackages = lib.mkDefault true;
      sharedModules = [];
      backupCommand = "${pkgs.rm-improved}/bin/rip";
      extraSpecialArgs = {
        inherit inputs globals system pkgs mylib;
        nixos_config = config;
        nixos_options = options;
        secrets = inputs.mysecrets;
        public = lav.public {};
      };
      overwriteBackup = true;
    };
    # needed for home-manager portal/DE configs be linked
    environment.pathsToLink = [
      "/share/applications"
      "/share/xdg-desktop-portal"
    ];
  };
}
