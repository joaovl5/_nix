{lav, ...}: let
  hm_config = {
    inputs,
    lib,
    pkgs,
    config,
    options,
    mylib,
    globals,
    ...
  }: {
    home-manager = {
      useGlobalPkgs = lib.mkDefault true;
      useUserPackages = lib.mkDefault true;
      sharedModules = [];
      backupCommand = "${pkgs.rm-improved}/bin/rip";
      extraSpecialArgs = {
        inherit inputs globals pkgs mylib;
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

  host_uses_home_manager = host: let
    users = builtins.attrValues (host.users or {});
    has_home_manager_user =
      builtins.any
      (user: builtins.elem "homeManager" (user.classes or []))
      users;
  in
    has_home_manager_user;
in {
  den.aspects.base-home-manager = {host}:
    if host_uses_home_manager host
    then {nixos = hm_config;}
    else {};

  # Used by legacy compatibility outputs, where the HM module is still imported explicitly.
  den.aspects.base-home-manager-compat.nixos = hm_config;
}
