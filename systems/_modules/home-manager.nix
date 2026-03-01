{
  inputs,
  lib,
  pkgs,
  config,
  options,
  system,
  mylib,
  ...
} @ args: {
  imports = with inputs; [
    hm.nixosModules.home-manager
  ];

  home-manager = {
    useGlobalPkgs = lib.mkDefault true;
    useUserPackages = lib.mkDefault true;
    sharedModules = [];
    backupCommand = "${pkgs.rm-improved}/bin/rip";
    extraSpecialArgs = {
      inherit inputs system pkgs mylib;
      nixos_config = config;
      nixos_options = options;
      secrets = inputs.mysecrets;
      public = import ../../_modules/public.nix args;
    };
    overwriteBackup = true;
  };
  # needed for home-manager portal/DE configs be linked
  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];
}
